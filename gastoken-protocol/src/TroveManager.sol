// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IGasToken.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";

contract TroveManager is LiquityBase, Ownable, CheckContract, ITroveManager {
    string public constant NAME = "TroveManager";

    // --- Connected contract declarations ---

    address public borrowerOperationsAddress;

    address gasPoolAddress;

    IGasToken public override gasToken;

    // A doubly linked list of Troves, sorted by their sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    // --- Data structures ---

    uint256 public constant REDEMPTION_FEE = DECIMAL_PRECISION / 1000 * 5; // 0.5%

    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    // Store the necessary data for a trove
    struct Trove {
        uint256 debt;
        uint256 coll;
        Status status;
        uint128 arrayIndex;
    }

    mapping(address => Trove) public Troves;

    // Array of all active trove addresses - used to to compute an approximate hint off-chain, for the sorted list insertion
    address[] public TroveOwners;

    /*
    * --- Variable container structs for liquidations ---
    *
    * These structs are used to hold, return and assign variables inside the liquidation functions,
    * in order to avoid the error: "CompilerError: Stack too deep".
    **/

    struct LocalVariables_OuterLiquidationFunction {
        uint256 price;
        uint256 liquidatedDebt;
        uint256 liquidatedColl;
    }

    struct LocalVariables_LiquidationSequence {
        uint256 i;
        uint256 ICR;
        address user;
    }

    struct LiquidationValues {
        uint256 entireTroveDebt;
        uint256 entireTroveColl;
        uint256 debtToOffset;
        uint256 debtToRedistribute;
        uint256 collToRedistribute;
    }

    struct LiquidationTotals {
        uint256 totalCollInSequence;
        uint256 totalDebtInSequence;
        uint256 totalDebtToOffset;
        uint256 totalDebtToRedistribute;
        uint256 totalCollToRedistribute;
    }

    struct ContractsCache {
        IActivePool activePool;
        IGasToken gasToken;
        ISortedTroves sortedTroves;
        address gasPoolAddress;
    }
    // --- Variable container structs for redemptions ---

    struct RedemptionTotals {
        uint256 remainingGASETH;
        uint256 totalGASETHToRedeem;
        uint256 totalETHDrawn;
        uint256 ETHFee;
        uint256 ETHToSendToRedeemer;
        uint256 price;
    }

    struct SingleRedemptionValues {
        uint256 GASETHLot;
        uint256 ETHLot;
        bool cancelledPartial;
    }

    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event GasTokenAddressChanged(address _newGasTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);

    event Liquidation(uint256 _liquidatedDebt, uint256 _liquidatedColl);
    event Redemption(uint256 _attemptedGASETHAmount, uint256 _actualGASETHAmount, uint256 _ETHSent, uint256 _ETHFee);
    event TroveUpdated(
        address indexed _borrower, uint256 _debt, uint256 _coll, TroveManagerOperation _operation
    );
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, TroveManagerOperation _operation);
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);

    enum TroveManagerOperation {
        liquidateInNormalMode,
        redeemCollateral
    }

    // --- Dependency setter ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _gasPoolAddress,
        address _priceFeedAddress,
        address _gasTokenAddress,
        address _sortedTrovesAddress
    ) external override onlyOwner {
        checkContract(_borrowerOperationsAddress);
        checkContract(_activePoolAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_gasPoolAddress);
        checkContract(_priceFeedAddress);
        checkContract(_gasTokenAddress);
        checkContract(_sortedTrovesAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePool = IActivePool(_activePoolAddress);
        gasPoolAddress = _gasPoolAddress;
        priceFeed = IPriceFeed(_priceFeedAddress);
        gasToken = IGasToken(_gasTokenAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit GasTokenAddressChanged(_gasTokenAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);

        _renounceOwnership();
    }

    // --- Getters ---

    function getTroveOwnersCount() external view override returns (uint256) {
        return TroveOwners.length;
    }

    function getTroveFromTroveOwnersArray(uint256 _index) external view override returns (address) {
        return TroveOwners[_index];
    }

    // --- Trove Liquidation functions ---

    // Single liquidation function. Closes the trove if its ICR is lower than the minimum collateral ratio.
    function liquidate(address _borrower) external override {
        _requireTroveIsActive(_borrower);

        address[] memory borrowers = new address[](1);
        borrowers[0] = _borrower;
        batchLiquidateTroves(borrowers, msg.sender);
    }

    // --- Inner single liquidation functions ---

    // Liquidate one trove, in Normal Mode.
    function _liquidateNormalMode(IActivePool _activePool, address _borrower, address liquidator)
        internal
        returns (LiquidationValues memory singleLiquidation)
    {
        ContractsCache memory contractsCache = ContractsCache(_activePool, gasToken, sortedTroves, gasPoolAddress);
        (
            singleLiquidation.entireTroveDebt,
            singleLiquidation.entireTroveColl,
        ) = getEntireDebtAndColl(_borrower);

        (singleLiquidation.debtToOffset, singleLiquidation.debtToRedistribute, singleLiquidation.collToRedistribute) =
            _getOffsetAndRedistributionVals(singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl);

        _closeTrove(_borrower, Status.closedByLiquidation);

        // Send eth to liquidator in exchange of GASETH
        _contractsCache.gasToken.burn(liquidator, singleLiquidation.debtToRedistribute);
        _contractsCache.activePool.decreaseGASETHDebt(singleLiquidation.debtToRedistribute);
        _contractsCache.activePool.sendETH(
            liquidator,
            singleLiquidation.collToRedistribute
        );

        emit TroveLiquidated(
            _borrower,
            singleLiquidation.entireTroveDebt,
            singleLiquidation.entireTroveColl,
            TroveManagerOperation.liquidateInNormalMode
        );
        emit TroveUpdated(_borrower, 0, 0, TroveManagerOperation.liquidateInNormalMode);
        return singleLiquidation;
    }

    /* In a full liquidation, returns the values for a trove's coll and debt to be offset, and coll and debt to be
    * redistributed to active troves.
    */
    function _getOffsetAndRedistributionVals(uint256 _debt, uint256 _coll)
        internal
        pure
        returns (uint256 debtToOffset, uint256 debtToRedistribute, uint256 collToRedistribute)
    {
        debtToOffset = 0;
        debtToRedistribute = _debt;
        collToRedistribute = _coll;
    }

    /*
    * Liquidate a sequence of troves. Closes a maximum number of n under-collateralized Troves,
    * starting from the one with the lowest collateral ratio in the system, and moving upwards
    */
    function liquidateTroves(uint256 _n) external override {
        ContractsCache memory contractsCache =
            ContractsCache(activePool, IGasToken(address(0)), sortedTroves, address(0));

        LocalVariables_OuterLiquidationFunction memory vars;

        LiquidationTotals memory totals;

        vars.price = priceFeed.fetchPrice();

        // Perform the appropriate liquidation sequence - tally the values, and obtain their totals
        totals = _getTotalsFromLiquidateTrovesSequence_NormalMode(contractsCache.activePool, vars.price, _n, msg.sender);

        require(totals.totalDebtInSequence > 0, "TroveManager: nothing to liquidate");

        vars.liquidatedDebt = totals.totalDebtInSequence;
        vars.liquidatedColl = totals.totalCollInSequence;
        emit Liquidation(vars.liquidatedDebt, vars.liquidatedColl);
    }

    function _getTotalsFromLiquidateTrovesSequence_NormalMode(IActivePool _activePool, uint256 _price, uint256 _n, address liquidator)
        internal
        returns (LiquidationTotals memory totals)
    {
        LocalVariables_LiquidationSequence memory vars;
        LiquidationValues memory singleLiquidation;
        ISortedTroves sortedTrovesCached = sortedTroves;

        for (vars.i = 0; vars.i < _n; vars.i++) {
            vars.user = sortedTrovesCached.getLast();
            vars.ICR = getCurrentICR(vars.user, _price);

            if (vars.ICR < MCR) {
                singleLiquidation = _liquidateNormalMode(_activePool, vars.user, liquidator);
`
                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);
            } else {
                break;
            } // break if the loop reaches a Trove with ICR >= MCR
        }
    }

    /*
    * Attempt to liquidate a custom list of troves provided by the caller.
    */
    function batchLiquidateTroves(address[] memory _troveArray, address liquidator) public override {
        require(_troveArray.length != 0, "TroveManager: Calldata address array must not be empty");

        IActivePool activePoolCached = activePool;

        LocalVariables_OuterLiquidationFunction memory vars;
        LiquidationTotals memory totals;

        vars.price = priceFeed.fetchPrice();

        // Perform the appropriate liquidation sequence - tally values and obtain their totals.
        totals = _getTotalsFromBatchLiquidate_NormalMode(activePoolCached, vars.price, _troveArray, liquidator);

        require(totals.totalDebtInSequence > 0, "TroveManager: nothing to liquidate");

        vars.liquidatedDebt = totals.totalDebtInSequence;
        vars.liquidatedColl = totals.totalCollInSequence;
        emit Liquidation(vars.liquidatedDebt, vars.liquidatedColl);
    }

    function _getTotalsFromBatchLiquidate_NormalMode(
        IActivePool _activePool,
        uint256 _price,
        address[] memory _troveArray,
        address liquidator
    ) internal returns (LiquidationTotals memory totals) {
        LocalVariables_LiquidationSequence memory vars;
        LiquidationValues memory singleLiquidation;

        for (vars.i = 0; vars.i < _troveArray.length; vars.i++) {
            vars.user = _troveArray[vars.i];
            vars.ICR = getCurrentICR(vars.user, _price);

            if (vars.ICR < MCR) {
                singleLiquidation = _liquidateNormalMode(_activePool, vars.user, liquidator);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(totals, singleLiquidation);
            }
        }
    }

    // --- Liquidation helper functions ---

    function _addLiquidationValuesToTotals(
        LiquidationTotals memory oldTotals,
        LiquidationValues memory singleLiquidation
    ) internal pure returns (LiquidationTotals memory newTotals) {
        // Tally all the values with their respective running totals
        newTotals.totalDebtInSequence = oldTotals.totalDebtInSequence.add(singleLiquidation.entireTroveDebt);
        newTotals.totalCollInSequence = oldTotals.totalCollInSequence.add(singleLiquidation.entireTroveColl);
        newTotals.totalDebtToOffset = oldTotals.totalDebtToOffset.add(singleLiquidation.debtToOffset);
        newTotals.totalDebtToRedistribute = oldTotals.totalDebtToRedistribute.add(singleLiquidation.debtToRedistribute);
        newTotals.totalCollToRedistribute = oldTotals.totalCollToRedistribute.add(singleLiquidation.collToRedistribute);

        return newTotals;
    }

    // --- Redemption functions ---

    // Redeem as much collateral as possible from _borrower's Trove in exchange for GASETH up to _maxGASETHamount
    function _redeemCollateralFromTrove(
        ContractsCache memory _contractsCache,
        address _borrower,
        uint256 _maxGASETHamount,
        uint256 _price,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR
    ) internal returns (SingleRedemptionValues memory singleRedemption) {
        // Determine the remaining amount (lot) to be redeemed, capped by the entire debt of the Trove minus the liquidation reserve
        singleRedemption.GASETHLot = LiquityMath._min(_maxGASETHamount, Troves[_borrower].debt);

        // Get the ETHLot of equivalent value in GasToken
        singleRedemption.ETHLot = singleRedemption.GASETHLot.mul(DECIMAL_PRECISION).div(_price);

        // Decrease the debt and collateral of the current Trove according to the GASETH lot and corresponding ETH to send
        uint256 newDebt = (Troves[_borrower].debt).sub(singleRedemption.GASETHLot);
        uint256 newColl = (Troves[_borrower].coll).sub(singleRedemption.ETHLot);

        if (newDebt == 0) {
            // No debt left in the Trove (except for the liquidation reserve), therefore the trove gets closed
            _closeTrove(_borrower, Status.closedByRedemption);
            _redeemCloseTrove(_contractsCache, _borrower, GASETH_GAS_COMPENSATION, newColl);
            emit TroveUpdated(_borrower, 0, 0, TroveManagerOperation.redeemCollateral);
        } else {
            uint256 newNICR = LiquityMath._computeNominalCR(newColl, newDebt);

            /*
            * If the provided hint is out of date, we bail since trying to reinsert without a good hint will almost
            * certainly result in running out of gas. 
            *
            * If the resultant net debt of the partial is less than the minimum, net debt we bail.
            */
            if (newNICR != _partialRedemptionHintNICR || _getNetDebt(newDebt) < MIN_NET_DEBT) {
                singleRedemption.cancelledPartial = true;
                return singleRedemption;
            }

            _contractsCache.sortedTroves.reInsert(
                _borrower, newNICR, _upperPartialRedemptionHint, _lowerPartialRedemptionHint
            );

            Troves[_borrower].debt = newDebt;
            Troves[_borrower].coll = newColl;

            emit TroveUpdated(
                _borrower, newDebt, newColl, TroveManagerOperation.redeemCollateral
            );
        }

        return singleRedemption;
    }

    /*
    * Called when a full redemption occurs, and closes the trove.
    * The redeemer swaps (debt - liquidation reserve) GASETH for (debt - liquidation reserve) worth of ETH, so the GASETH liquidation reserve left corresponds to the remaining debt.
    * In order to close the trove, the GASETH liquidation reserve is burned, and the corresponding debt is removed from the active pool.
    * The debt recorded on the trove's struct is zero'd elswhere, in _closeTrove.
    * Any surplus ETH left in the trove, is sent to the borrower.
    */
    function _redeemCloseTrove(ContractsCache memory _contractsCache, address _borrower, uint256 _GASETH, uint256 _ETH)
        internal
    {
        _contractsCache.gasToken.burn(gasPoolAddress, _GASETH);
        // Update Active Pool GASETH, and send ETH to account
        _contractsCache.activePool.decreaseGASETHDebt(_GASETH);
        _contractsCache.activePool.sendETH(
            _borrower,
            _ETH
        );
    }

    function _isValidFirstRedemptionHint(ISortedTroves _sortedTroves, address _firstRedemptionHint, uint256 _price)
        internal
        view
        returns (bool)
    {
        if (
            _firstRedemptionHint == address(0) || !_sortedTroves.contains(_firstRedemptionHint)
                || getCurrentICR(_firstRedemptionHint, _price) < MCR
        ) {
            return false;
        }

        address nextTrove = _sortedTroves.getNext(_firstRedemptionHint);
        return nextTrove == address(0) || getCurrentICR(nextTrove, _price) < MCR;
    }

    /* Send _GASETHamount GASETH to the system and redeem the corresponding amount of collateral from as many Troves as are needed to fill the redemption
    * request.  Applies pending rewards to a Trove before reducing its debt and coll.
    *
    * Note that if _amount is very large, this function can run out of gas, specially if traversed troves are small. This can be easily avoided by
    * splitting the total _amount in appropriate chunks and calling the function multiple times.
    *
    * Param `_maxIterations` can also be provided, so the loop through Troves is capped (if it’s zero, it will be ignored).This makes it easier to
    * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
    * of the trove list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
    * costs can vary.
    *
    * All Troves that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
    * If the last Trove does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
    * A frontend should use getRedemptionHints() to calculate what the ICR of this Trove will be after redemption, and pass a hint for its position
    * in the sortedTroves list along with the ICR value that the hint was found for.
    *
    * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
    * is very likely that the last (partially) redeemed Trove would end up with a different ICR than what the hint is for. In this case the
    * redemption will stop after the last completely redeemed Trove and the sender will keep the remaining GASETH amount, which they can attempt
    * to redeem later.
    */
    function redeemCollateral(
        uint256 _GASETHamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations
    ) external override {
        ContractsCache memory contractsCache = ContractsCache(activePool, gasToken, sortedTroves, gasPoolAddress);
        RedemptionTotals memory totals;

        totals.price = priceFeed.fetchPrice();
        _requireTCRoverMCR(totals.price);
        _requireAmountGreaterThanZero(_GASETHamount);
        _requireGASETHBalanceCoversRedemption(contractsCache.gasToken, msg.sender, _GASETHamount);

        totals.remainingGASETH = _GASETHamount;
        address currentBorrower;

        if (_isValidFirstRedemptionHint(contractsCache.sortedTroves, _firstRedemptionHint, totals.price)) {
            currentBorrower = _firstRedemptionHint;
        } else {
            currentBorrower = contractsCache.sortedTroves.getLast();
            // Find the first trove with ICR >= MCR
            while (currentBorrower != address(0) && getCurrentICR(currentBorrower, totals.price) < MCR) {
                currentBorrower = contractsCache.sortedTroves.getPrev(currentBorrower);
            }
        }

        // Loop through the Troves starting from the one with lowest collateral ratio until _amount of GASETH is exchanged for collateral
        if (_maxIterations == 0) _maxIterations = uint256(-1);
        while (currentBorrower != address(0) && totals.remainingGASETH > 0 && _maxIterations > 0) {
            _maxIterations--;
            // Save the address of the Trove preceding the current one, before potentially modifying the list
            address nextUserToCheck = contractsCache.sortedTroves.getPrev(currentBorrower);

            SingleRedemptionValues memory singleRedemption = _redeemCollateralFromTrove(
                contractsCache,
                currentBorrower,
                totals.remainingGASETH,
                totals.price,
                _upperPartialRedemptionHint,
                _lowerPartialRedemptionHint,
                _partialRedemptionHintNICR
            );

            if (singleRedemption.cancelledPartial) break; // Partial redemption was cancelled (out-of-date hint, or new net debt < minimum), therefore we could not redeem from the last Trove

            totals.totalGASETHToRedeem = totals.totalGASETHToRedeem.add(singleRedemption.GASETHLot);
            totals.totalETHDrawn = totals.totalETHDrawn.add(singleRedemption.ETHLot);

            totals.remainingGASETH = totals.remainingGASETH.sub(singleRedemption.GASETHLot);
            currentBorrower = nextUserToCheck;
        }
        require(totals.totalETHDrawn > 0, "TroveManager: Unable to redeem any amount");

        // Calculate the ETH fee
        totals.ETHFee = getRedemptionFee(totals.totalETHDrawn);

        totals.ETHToSendToRedeemer = totals.totalETHDrawn.sub(totals.ETHFee);

        emit Redemption(_GASETHamount, totals.totalGASETHToRedeem, totals.totalETHDrawn, totals.ETHFee);

        // Burn the total GASETH that is cancelled with debt, and send the redeemed ETH to msg.sender
        contractsCache.gasToken.burn(msg.sender, totals.totalGASETHToRedeem);
        // Update Active Pool GASETH, and send ETH to account
        contractsCache.activePool.decreaseGASETHDebt(totals.totalGASETHToRedeem);
        contractsCache.activePool.sendETH(msg.sender, totals.ETHToSendToRedeemer);
    }

    // --- Helper functions ---

    // Return the nominal collateral ratio (ICR) of a given Trove, without the price. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getNominalICR(address _borrower) public view override returns (uint256) {
        (uint256 currentETH, uint256 currentGASETHDebt) = _getCurrentTroveAmounts(_borrower);

        uint256 NICR = LiquityMath._computeNominalCR(currentETH, currentGASETHDebt);
        return NICR;
    }

    // Return the current collateral ratio (ICR) of a given Trove. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getCurrentICR(address _borrower, uint256 _price) public view override returns (uint256) {
        (uint256 currentETH, uint256 currentGASETHDebt) = _getCurrentTroveAmounts(_borrower);

        uint256 ICR = LiquityMath._computeCR(currentETH, currentGASETHDebt, _price);
        return ICR;
    }

    function _getCurrentTroveAmounts(address _borrower) internal view returns (uint256, uint256) {
        uint256 currentETH = Troves[_borrower].coll;
        uint256 currentGASETHDebt = Troves[_borrower].debt;

        return (currentETH, currentGASETHDebt);
    }

    // Return the Troves entire debt and coll.
    function getEntireDebtAndColl(address _borrower) public view override returns (uint256 debt, uint256 coll) {
        debt = Troves[_borrower].debt;
        coll = Troves[_borrower].coll;
    }

    function closeTrove(address _borrower) external override {
        _requireCallerIsBorrowerOperations();
        return _closeTrove(_borrower, Status.closedByOwner);
    }

    function _closeTrove(address _borrower, Status closedStatus) internal {
        assert(closedStatus != Status.nonExistent && closedStatus != Status.active);

        uint256 TroveOwnersArrayLength = TroveOwners.length;
        _requireMoreThanOneTroveInSystem(TroveOwnersArrayLength);

        Troves[_borrower].status = closedStatus;
        Troves[_borrower].coll = 0;
        Troves[_borrower].debt = 0;

        _removeTroveOwner(_borrower, TroveOwnersArrayLength);
        sortedTroves.remove(_borrower);
    }

    // Push the owner's address to the Trove owners list, and record the corresponding array index on the Trove struct
    function addTroveOwnerToArray(address _borrower) external override returns (uint256 index) {
        _requireCallerIsBorrowerOperations();
        return _addTroveOwnerToArray(_borrower);
    }

    function _addTroveOwnerToArray(address _borrower) internal returns (uint128 index) {
        /* Max array size is 2**128 - 1, i.e. ~3e30 troves. No risk of overflow, since troves have minimum GASETH
        debt of liquidation reserve plus MIN_NET_DEBT. 3e30 GASETH dwarfs the value of all wealth in the world ( which is < 1e15 USD). */

        // Push the Troveowner to the array
        TroveOwners.push(_borrower);

        // Record the index of the new Troveowner on their Trove struct
        index = uint128(TroveOwners.length.sub(1));
        Troves[_borrower].arrayIndex = index;

        return index;
    }

    /*
    * Remove a Trove owner from the TroveOwners array, not preserving array order. Removing owner 'B' does the following:
    * [A B C D E] => [A E C D], and updates E's Trove struct to point to its new array index.
    */
    function _removeTroveOwner(address _borrower, uint256 TroveOwnersArrayLength) internal {
        Status troveStatus = Troves[_borrower].status;
        // It’s set in caller function `_closeTrove`
        assert(troveStatus != Status.nonExistent && troveStatus != Status.active);

        uint128 index = Troves[_borrower].arrayIndex;
        uint256 length = TroveOwnersArrayLength;
        uint256 idxLast = length.sub(1);

        assert(index <= idxLast);

        address addressToMove = TroveOwners[idxLast];

        TroveOwners[index] = addressToMove;
        Troves[addressToMove].arrayIndex = index;
        emit TroveIndexUpdated(addressToMove, index);

        TroveOwners.pop();
    }

    // --- Redemption fee functions ---

    function getRedemptionRate() public view override returns (uint256) {
        return REDEMPTION_FEE;
    }

    function getRedemptionFee(uint256 _ETHDrawn) public view override returns (uint256) {
        return _calcRedemptionFee(getRedemptionRate(), _ETHDrawn);
    }

    function _calcRedemptionFee(uint256 _redemptionRate, uint256 _ETHDrawn) internal pure returns (uint256) {
        uint256 redemptionFee = _redemptionRate.mul(_ETHDrawn).div(DECIMAL_PRECISION);
        require(redemptionFee < _ETHDrawn, "TroveManager: Fee would eat up all returned collateral");
        return redemptionFee;
    }

    // --- Borrowing fee functions ---

    function getBorrowingRate() public view override returns (uint256) {
        return BORROWING_FEE;
    }

    function getBorrowingFee(uint256 _GASETHDebt) external view override returns (uint256) {
        return _calcBorrowingFee(getBorrowingRate(), _GASETHDebt);
    }

    function _calcBorrowingFee(uint256 _borrowingRate, uint256 _GASETHDebt) internal pure returns (uint256) {
        return _borrowingRate.mul(_GASETHDebt).div(DECIMAL_PRECISION);
    }

    // --- 'require' wrapper functions ---

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "TroveManager: Caller is not the BorrowerOperations contract");
    }

    function _requireTroveIsActive(address _borrower) internal view {
        require(Troves[_borrower].status == Status.active, "TroveManager: Trove does not exist or is closed");
    }

    function _requireGASETHBalanceCoversRedemption(IGasToken _gasToken, address _redeemer, uint256 _amount)
        internal
        view
    {
        require(
            _gasToken.balanceOf(_redeemer) >= _amount,
            "TroveManager: Requested redemption amount must be <= user's GASETH token balance"
        );
    }

    function _requireMoreThanOneTroveInSystem(uint256 TroveOwnersArrayLength) internal view {
        require(TroveOwnersArrayLength > 1 && sortedTroves.getSize() > 1, "TroveManager: Only one trove in the system");
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        require(_amount > 0, "TroveManager: Amount must be greater than zero");
    }

    function _requireTCRoverMCR(uint256 _price) internal view {
        require(_getTCR(_price) >= MCR, "TroveManager: Cannot redeem when TCR < MCR");
    }

    // --- Trove property getters ---

    function getTroveStatus(address _borrower) external view override returns (uint256) {
        return uint256(Troves[_borrower].status);
    }

    function getTroveDebt(address _borrower) external view override returns (uint256) {
        return Troves[_borrower].debt;
    }

    function getTroveColl(address _borrower) external view override returns (uint256) {
        return Troves[_borrower].coll;
    }

    // --- Trove property setters, called by BorrowerOperations ---

    function setTroveStatus(address _borrower, uint256 _num) external override {
        _requireCallerIsBorrowerOperations();
        Troves[_borrower].status = Status(_num);
    }

    function increaseTroveColl(address _borrower, uint256 _collIncrease) external override returns (uint256) {
        _requireCallerIsBorrowerOperations();
        uint256 newColl = Troves[_borrower].coll.add(_collIncrease);
        Troves[_borrower].coll = newColl;
        return newColl;
    }

    function decreaseTroveColl(address _borrower, uint256 _collDecrease) external override returns (uint256) {
        _requireCallerIsBorrowerOperations();
        uint256 newColl = Troves[_borrower].coll.sub(_collDecrease);
        Troves[_borrower].coll = newColl;
        return newColl;
    }

    function increaseTroveDebt(address _borrower, uint256 _debtIncrease) external override returns (uint256) {
        _requireCallerIsBorrowerOperations();
        uint256 newDebt = Troves[_borrower].debt.add(_debtIncrease);
        Troves[_borrower].debt = newDebt;
        return newDebt;
    }

    function decreaseTroveDebt(address _borrower, uint256 _debtDecrease) external override returns (uint256) {
        _requireCallerIsBorrowerOperations();
        uint256 newDebt = Troves[_borrower].debt.sub(_debtDecrease);
        Troves[_borrower].debt = newDebt;
        return newDebt;
    }
}

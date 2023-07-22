// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./Interfaces/IBorrowerOperations.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IGasToken.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Dependencies/LiquityBase.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";

contract BorrowerOperations is LiquityBase, Ownable, CheckContract, IBorrowerOperations {
    string public constant NAME = "BorrowerOperations";

    // --- Connected contract declarations ---

    ITroveManager public troveManager;

    address gasPoolAddress;

    IGasToken public gasToken;

    // A doubly linked list of Troves, sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    /* --- Variable container structs  ---

    Used to hold, return and assign variables inside a function, in order to avoid the error:
    "CompilerError: Stack too deep". */

    struct LocalVariables_adjustTrove {
        uint256 price;
        uint256 collChange;
        uint256 netDebtChange;
        bool isCollIncrease;
        uint256 debt;
        uint256 coll;
        uint256 oldICR;
        uint256 newICR;
        uint256 newTCR;
        uint256 GASETHFee;
        uint256 newDebt;
        uint256 newColl;
    }

    struct LocalVariables_openTrove {
        uint256 price;
        uint256 GASETHFee;
        uint256 netDebt;
        uint256 compositeDebt;
        uint256 ICR;
        uint256 NICR;
        uint256 arrayIndex;
    }

    struct ContractsCache {
        ITroveManager troveManager;
        IActivePool activePool;
        IGasToken gasToken;
    }

    enum BorrowerOperation {
        openTrove,
        closeTrove,
        adjustTrove
    }

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event GasTokenAddressChanged(address _gasTokenAddress);

    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, BorrowerOperation operation);
    event GASETHBorrowingFeePaid(address indexed _borrower, uint256 _GASETHFee);

    // --- Dependency setters ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress,
        address _gasPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _gasTokenAddress
    ) external override onlyOwner {
        // This makes impossible to open a trove with zero withdrawn GASETH
        assert(MIN_NET_DEBT > 0);

        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);
        checkContract(_gasPoolAddress);
        checkContract(_priceFeedAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_gasTokenAddress);

        troveManager = ITroveManager(_troveManagerAddress);
        activePool = IActivePool(_activePoolAddress);
        gasPoolAddress = _gasPoolAddress;
        priceFeed = IPriceFeed(_priceFeedAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        gasToken = IGasToken(_gasTokenAddress);

        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit GasTokenAddressChanged(_gasTokenAddress);

        _renounceOwnership();
    }

    // --- Borrower Trove Operations ---

    function openTrove(uint256 _maxFeePercentage, uint256 _GASETHAmount, address _upperHint, address _lowerHint)
        external
        payable
        override
    {
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, gasToken);
        LocalVariables_openTrove memory vars;

        vars.price = priceFeed.fetchPrice();

        _requireTroveisNotActive(contractsCache.troveManager, msg.sender);

        vars.GASETHFee;
        vars.netDebt = _GASETHAmount;

        _requireAtLeastMinNetDebt(vars.netDebt);

        // ICR is based on the composite debt, i.e. the requested GASETH amount + GASETH borrowing fee + GASETH gas comp.
        vars.compositeDebt = vars.netDebt;
        assert(vars.compositeDebt > 0);

        vars.ICR = LiquityMath._computeCR(msg.value, vars.compositeDebt, vars.price);
        vars.NICR = LiquityMath._computeNominalCR(msg.value, vars.compositeDebt);

        _requireICRisAboveMCR(vars.ICR);
        uint256 newTCR = _getNewTCRFromTroveChange(msg.value, true, vars.compositeDebt, true, vars.price); // bools: coll increase, debt increase

        // Set the trove struct's properties
        contractsCache.troveManager.setTroveStatus(msg.sender, 1);
        contractsCache.troveManager.increaseTroveColl(msg.sender, msg.value);
        contractsCache.troveManager.increaseTroveDebt(msg.sender, vars.compositeDebt);

        sortedTroves.insert(msg.sender, vars.NICR, _upperHint, _lowerHint);
        vars.arrayIndex = contractsCache.troveManager.addTroveOwnerToArray(msg.sender);
        emit TroveCreated(msg.sender, vars.arrayIndex);

        // Move the ether to the Active Pool, and mint the GASETHAmount to the borrower
        _activePoolAddColl(contractsCache.activePool, msg.value);
        _withdrawGASETH(contractsCache.activePool, contractsCache.gasToken, msg.sender, _GASETHAmount, vars.netDebt);

        emit TroveUpdated(msg.sender, vars.compositeDebt, msg.value, BorrowerOperation.openTrove);
        emit GASETHBorrowingFeePaid(msg.sender, vars.GASETHFee);
    }

    // Send ETH as collateral to a trove
    function addColl(address _upperHint, address _lowerHint) external payable override {
        _adjustTrove(msg.sender, 0, 0, false, _upperHint, _lowerHint, 0);
    }

    // Withdraw ETH collateral from a trove
    function withdrawColl(uint256 _collWithdrawal, address _upperHint, address _lowerHint) external override {
        _adjustTrove(msg.sender, _collWithdrawal, 0, false, _upperHint, _lowerHint, 0);
    }

    // Withdraw GASETH tokens from a trove: mint new GASETH tokens to the owner, and increase the trove's debt accordingly
    function withdrawGASETH(uint256 _maxFeePercentage, uint256 _GASETHAmount, address _upperHint, address _lowerHint)
        external
        override
    {
        _adjustTrove(msg.sender, 0, _GASETHAmount, true, _upperHint, _lowerHint, _maxFeePercentage);
    }

    // Repay GASETH tokens to a Trove: Burn the repaid GASETH tokens, and reduce the trove's debt accordingly
    function repayGASETH(uint256 _GASETHAmount, address _upperHint, address _lowerHint) external override {
        _adjustTrove(msg.sender, 0, _GASETHAmount, false, _upperHint, _lowerHint, 0);
    }

    function adjustTrove(
        uint256 _maxFeePercentage,
        uint256 _collWithdrawal,
        uint256 _GASETHChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        _adjustTrove(
            msg.sender, _collWithdrawal, _GASETHChange, _isDebtIncrease, _upperHint, _lowerHint, _maxFeePercentage
        );
    }

    /*
    * _adjustTrove(): Alongside a debt change, this function can perform either a collateral top-up or a collateral withdrawal. 
    *
    * It therefore expects either a positive msg.value, or a positive _collWithdrawal argument.
    *
    * If both are positive, it will revert.
    */
    function _adjustTrove(
        address _borrower,
        uint256 _collWithdrawal,
        uint256 _GASETHChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFeePercentage
    ) internal {
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, gasToken);
        LocalVariables_adjustTrove memory vars;

        vars.price = priceFeed.fetchPrice();

        if (_isDebtIncrease) {
            _requireNonZeroDebtChange(_GASETHChange);
        }
        _requireSingularCollChange(_collWithdrawal);
        _requireNonZeroAdjustment(_collWithdrawal, _GASETHChange);
        _requireTroveisActive(contractsCache.troveManager, _borrower);

        // Confirm the operation is a borrower adjusting their own trove
        assert(msg.sender == _borrower);

        // Get the collChange based on whether or not ETH was sent in the transaction
        (vars.collChange, vars.isCollIncrease) = _getCollChange(msg.value, _collWithdrawal);

        vars.netDebtChange = _GASETHChange;

        // If the adjustment incorporates a debt increase, then trigger a borrowing fee
        if (_isDebtIncrease) {
            vars.GASETHFee = _triggerBorrowingFee(contractsCache.troveManager, _GASETHChange);
            vars.netDebtChange = vars.netDebtChange.add(vars.GASETHFee); // The raw debt change includes the fee
        }

        vars.debt = contractsCache.troveManager.getTroveDebt(_borrower);
        vars.coll = contractsCache.troveManager.getTroveColl(_borrower);

        // Get the trove's old ICR before the adjustment, and what its new ICR will be after the adjustment
        vars.oldICR = LiquityMath._computeCR(vars.coll, vars.debt, vars.price);
        vars.newICR = _getNewICRFromTroveChange(
            vars.coll, vars.debt, vars.collChange, vars.isCollIncrease, vars.netDebtChange, _isDebtIncrease, vars.price
        );
        assert(_collWithdrawal <= vars.coll);

        // Check the adjustment satisfies all conditions for the current system mode
        _requireValidAdjustmentInCurrentMode(_collWithdrawal, _isDebtIncrease, vars);

        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough GASETH
        if (!_isDebtIncrease && _GASETHChange > 0) {
            _requireAtLeastMinNetDebt(_getNetDebt(vars.debt).sub(vars.netDebtChange));
            _requireValidGASETHRepayment(vars.debt, vars.netDebtChange);
            _requireSufficientGASETHBalance(contractsCache.gasToken, _borrower, vars.netDebtChange);
        }

        (vars.newColl, vars.newDebt) = _updateTroveFromAdjustment(
            contractsCache.troveManager,
            _borrower,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease
        );

        // Re-insert trove in to the sorted list
        uint256 newNICR = _getNewNominalICRFromTroveChange(
            vars.coll, vars.debt, vars.collChange, vars.isCollIncrease, vars.netDebtChange, _isDebtIncrease
        );
        sortedTroves.reInsert(_borrower, newNICR, _upperHint, _lowerHint);

        emit TroveUpdated(_borrower, vars.newDebt, vars.newColl, BorrowerOperation.adjustTrove);
        emit GASETHBorrowingFeePaid(msg.sender, vars.GASETHFee);

        // Use the unmodified _GASETHChange here, as we don't send the fee to the user
        _moveTokensAndETHfromAdjustment(
            contractsCache.activePool,
            contractsCache.gasToken,
            msg.sender,
            vars.collChange,
            vars.isCollIncrease,
            _GASETHChange,
            _isDebtIncrease,
            vars.netDebtChange
        );
    }

    function closeTrove() external override {
        ITroveManager troveManagerCached = troveManager;
        IActivePool activePoolCached = activePool;
        IGasToken gasTokenCached = gasToken;

        _requireTroveisActive(troveManagerCached, msg.sender);
        uint256 price = priceFeed.fetchPrice();

        uint256 coll = troveManagerCached.getTroveColl(msg.sender);
        uint256 debt = troveManagerCached.getTroveDebt(msg.sender);

        _requireSufficientGASETHBalance(gasTokenCached, msg.sender, debt.sub(GASETH_GAS_COMPENSATION));

        uint256 newTCR = _getNewTCRFromTroveChange(coll, false, debt, false, price);

        troveManagerCached.closeTrove(msg.sender);

        emit TroveUpdated(msg.sender, 0, 0, 0, BorrowerOperation.closeTrove);

        // Burn the repaid GASETH from the user's balance and the gas compensation from the Gas Pool
        _repayGASETH(activePoolCached, gasTokenCached, msg.sender, debt.sub(GASETH_GAS_COMPENSATION));
        _repayGASETH(activePoolCached, gasTokenCached, gasPoolAddress, GASETH_GAS_COMPENSATION);

        // Send the collateral back to the user
        activePoolCached.sendETH(msg.sender, coll);
    }

    // --- Helper functions ---

    function _triggerBorrowingFee(ITroveManager _troveManager, uint256 _GASETHAmount) internal returns (uint256) {
        uint256 GASETHFee = _troveManager.getBorrowingFee(_GASETHAmount);

        return GASETHFee;
    }

    function _getUSDValue(uint256 _coll, uint256 _price) internal pure returns (uint256) {
        uint256 usdValue = _price.mul(_coll).div(DECIMAL_PRECISION);

        return usdValue;
    }

    function _getCollChange(uint256 _collReceived, uint256 _requestedCollWithdrawal)
        internal
        pure
        returns (uint256 collChange, bool isCollIncrease)
    {
        if (_collReceived != 0) {
            collChange = _collReceived;
            isCollIncrease = true;
        } else {
            collChange = _requestedCollWithdrawal;
        }
    }

    // Update trove's coll and debt based on whether they increase or decrease
    function _updateTroveFromAdjustment(
        ITroveManager _troveManager,
        address _borrower,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal returns (uint256, uint256) {
        uint256 newColl = (_isCollIncrease)
            ? _troveManager.increaseTroveColl(_borrower, _collChange)
            : _troveManager.decreaseTroveColl(_borrower, _collChange);
        uint256 newDebt = (_isDebtIncrease)
            ? _troveManager.increaseTroveDebt(_borrower, _debtChange)
            : _troveManager.decreaseTroveDebt(_borrower, _debtChange);

        return (newColl, newDebt);
    }

    function _moveTokensAndETHfromAdjustment(
        IActivePool _activePool,
        IGasToken _gasToken,
        address _borrower,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _GASETHChange,
        bool _isDebtIncrease,
        uint256 _netDebtChange
    ) internal {
        if (_isDebtIncrease) {
            _withdrawGASETH(_activePool, _gasToken, _borrower, _GASETHChange, _netDebtChange);
        } else {
            _repayGASETH(_activePool, _gasToken, _borrower, _GASETHChange);
        }

        if (_isCollIncrease) {
            _activePoolAddColl(_activePool, _collChange);
        } else {
            _activePool.sendETH(_borrower, _collChange);
        }
    }

    // Send ETH to Active Pool and increase its recorded ETH balance
    function _activePoolAddColl(IActivePool _activePool, uint256 _amount) internal {
        (bool success,) = address(_activePool).call{value: _amount}("");
        require(success, "BorrowerOps: Sending ETH to ActivePool failed");
    }

    // Issue the specified amount of GASETH to _account and increases the total active debt (_netDebtIncrease potentially includes a GASETHFee)
    function _withdrawGASETH(
        IActivePool _activePool,
        IGasToken _gasToken,
        address _account,
        uint256 _GASETHAmount,
        uint256 _netDebtIncrease
    ) internal {
        _activePool.increaseGASETHDebt(_netDebtIncrease);
        _gasToken.mint(_account, _GASETHAmount);
    }

    // Burn the specified amount of GASETH from _account and decreases the total active debt
    function _repayGASETH(IActivePool _activePool, IGasToken _gasToken, address _account, uint256 _GASETH) internal {
        _activePool.decreaseGASETHDebt(_GASETH);
        _gasToken.burn(_account, _GASETH);
    }

    // --- 'Require' wrapper functions ---

    function _requireSingularCollChange(uint256 _collWithdrawal) internal view {
        require(msg.value == 0 || _collWithdrawal == 0, "BorrowerOperations: Cannot withdraw and add coll");
    }

    function _requireCallerIsBorrower(address _borrower) internal view {
        require(msg.sender == _borrower, "BorrowerOps: Caller must be the borrower for a withdrawal");
    }

    function _requireNonZeroAdjustment(uint256 _collWithdrawal, uint256 _GASETHChange) internal view {
        require(
            msg.value != 0 || _collWithdrawal != 0 || _GASETHChange != 0,
            "BorrowerOps: There must be either a collateral change or a debt change"
        );
    }

    function _requireTroveisActive(ITroveManager _troveManager, address _borrower) internal view {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status == 1, "BorrowerOps: Trove does not exist or is closed");
    }

    function _requireTroveisNotActive(ITroveManager _troveManager, address _borrower) internal view {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status != 1, "BorrowerOps: Trove is active");
    }

    function _requireNonZeroDebtChange(uint256 _GASETHChange) internal pure {
        require(_GASETHChange > 0, "BorrowerOps: Debt increase requires non-zero debtChange");
    }

    function _requireNoCollWithdrawal(uint256 _collWithdrawal) internal pure {
        require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
    }

    function _requireValidAdjustmentInCurrentMode(
        uint256 _collWithdrawal,
        bool _isDebtIncrease,
        LocalVariables_adjustTrove memory _vars
    ) internal view {
        _requireICRisAboveMCR(_vars.newICR);
        _vars.newTCR = _getNewTCRFromTroveChange(
            _vars.collChange, _vars.isCollIncrease, _vars.netDebtChange, _isDebtIncrease, _vars.price
        );
    }

    function _requireICRisAboveMCR(uint256 _newICR) internal pure {
        require(_newICR >= MCR, "BorrowerOps: An operation that would result in ICR < MCR is not permitted");
    }

    function _requireNewICRisAboveOldICR(uint256 _newICR, uint256 _oldICR) internal pure {
        require(_newICR >= _oldICR, "BorrowerOps: Cannot decrease your Trove's ICR in Recovery Mode");
    }

    function _requireAtLeastMinNetDebt(uint256 _netDebt) internal pure {
        require(_netDebt >= MIN_NET_DEBT, "BorrowerOps: Trove's net debt must be greater than minimum");
    }

    function _requireValidGASETHRepayment(uint256 _currentDebt, uint256 _debtRepayment) internal pure {
        require(
            _debtRepayment <= _currentDebt.sub(GASETH_GAS_COMPENSATION),
            "BorrowerOps: Amount repaid must not be larger than the Trove's debt"
        );
    }

    function _requireSufficientGASETHBalance(IGasToken _gasToken, address _borrower, uint256 _debtRepayment)
        internal
        view
    {
        require(
            _gasToken.balanceOf(_borrower) >= _debtRepayment,
            "BorrowerOps: Caller doesnt have enough GASETH to make repayment"
        );
    }

    // --- ICR and TCR getters ---

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewNominalICRFromTroveChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256) {
        (uint256 newColl, uint256 newDebt) =
            _getNewTroveAmounts(_coll, _debt, _collChange, _isCollIncrease, _debtChange, _isDebtIncrease);

        uint256 newNICR = LiquityMath._computeNominalCR(newColl, newDebt);
        return newNICR;
    }

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewICRFromTroveChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal pure returns (uint256) {
        (uint256 newColl, uint256 newDebt) =
            _getNewTroveAmounts(_coll, _debt, _collChange, _isCollIncrease, _debtChange, _isDebtIncrease);

        uint256 newICR = LiquityMath._computeCR(newColl, newDebt, _price);
        return newICR;
    }

    function _getNewTroveAmounts(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256, uint256) {
        uint256 newColl = _coll;
        uint256 newDebt = _debt;

        newColl = _isCollIncrease ? _coll.add(_collChange) : _coll.sub(_collChange);
        newDebt = _isDebtIncrease ? _debt.add(_debtChange) : _debt.sub(_debtChange);

        return (newColl, newDebt);
    }

    function _getNewTCRFromTroveChange(
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal view returns (uint256) {
        uint256 totalColl = getEntireSystemColl();
        uint256 totalDebt = getEntireSystemDebt();

        totalColl = _isCollIncrease ? totalColl.add(_collChange) : totalColl.sub(_collChange);
        totalDebt = _isDebtIncrease ? totalDebt.add(_debtChange) : totalDebt.sub(_debtChange);

        uint256 newTCR = LiquityMath._computeCR(totalColl, totalDebt, _price);
        return newTCR;
    }
}

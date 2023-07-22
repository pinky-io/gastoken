// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./ILiquityBase.sol";
import "./IGasToken.sol";

// Common interface for the Trove Manager.
interface ITroveManager is ILiquityBase {
    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event GasTokenAddressChanged(address _newGasTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);

    event Liquidation(uint256 _liquidatedDebt, uint256 _liquidatedColl);
    event Redemption(uint256 _attemptedGASETHAmount, uint256 _actualGASETHAmount, uint256 _ETHSent, uint256 _ETHFee);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);

    // --- Functions ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _gasPoolAddress,
        address _priceFeedAddress,
        address _gasTokenAddress,
        address _sortedTrovesAddress
    ) external;

    function gasToken() external view returns (IGasToken);

    function getTroveOwnersCount() external view returns (uint256);

    function getTroveFromTroveOwnersArray(uint256 _index) external view returns (address);

    function getNominalICR(address _borrower) external view returns (uint256);
    function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);

    function liquidate(address _borrower) external;

    function liquidateTroves(uint256 _n) external;

    function batchLiquidateTroves(address[] calldata _troveArray, address liquidator) external;

    function redeemCollateral(
        uint256 _GASETHAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations
    ) external;

    function addTroveOwnerToArray(address _borrower) external returns (uint256 index);

    function getEntireDebtAndColl(address _borrower) external view returns (uint256 debt, uint256 coll);

    function closeTrove(address _borrower) external;

    function getRedemptionRate() external view returns (uint256);

    function getBorrowingRate() external view returns (uint256);

    function getBorrowingFee(uint256 GASETHDebt) external view returns (uint256);

    function getTroveStatus(address _borrower) external view returns (uint256);

    function getTroveDebt(address _borrower) external view returns (uint256);

    function getTroveColl(address _borrower) external view returns (uint256);

    function setTroveStatus(address _borrower, uint256 num) external;

    function increaseTroveColl(address _borrower, uint256 _collIncrease) external returns (uint256);

    function decreaseTroveColl(address _borrower, uint256 _collDecrease) external returns (uint256);

    function increaseTroveDebt(address _borrower, uint256 _debtIncrease) external returns (uint256);

    function decreaseTroveDebt(address _borrower, uint256 _collDecrease) external returns (uint256);

    function getTCR(uint256 _price) external view returns (uint256);
}

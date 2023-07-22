// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./BaseMath.sol";
import "./LiquityMath.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ILiquityBase.sol";

/* 
* Base contract for TroveManager and BorrowerOperations. Contains global system constants and
* common functions. 
*/
contract LiquityBase is BaseMath, ILiquityBase {
    using SafeMath for uint256;

    uint256 public constant _100pct = 1000000000000000000; // 1e18 == 100%

    // Minimum collateral ratio for individual troves
    uint256 public constant MCR = 1100000000000000000; // 110%

    uint256 public constant MIN_NET_DEBT = 1;

    uint256 public constant BORROWING_FEE = DECIMAL_PRECISION / 1000 * 5; // 0.5%

    IActivePool public activePool;

    IPriceFeed public override priceFeed;

    function getEntireSystemColl() public view returns (uint256 entireSystemColl) {
        uint256 activeColl = activePool.getETH();

        return activeColl;
    }

    function getEntireSystemDebt() public view returns (uint256 entireSystemDebt) {
        uint256 activeDebt = activePool.getGASETHDebt();

        return activeDebt;
    }

    function _getTCR(uint256 _price) internal view returns (uint256 TCR) {
        uint256 entireSystemColl = getEntireSystemColl();
        uint256 entireSystemDebt = getEntireSystemDebt();

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function _checkRecoveryMode(uint256) internal pure returns (bool) {
        return false;
    }

    function _requireUserAcceptsFee(uint256 _fee, uint256 _amount, uint256 _maxFeePercentage) internal pure {
        uint256 feePercentage = _fee.mul(DECIMAL_PRECISION).div(_amount);
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}

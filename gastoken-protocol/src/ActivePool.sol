// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Interfaces/IActivePool.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";

/*
 * The Active Pool holds the ETH collateral and GASETH debt (but not GASETH tokens) for all active troves.
 *
 * When a trove is liquidated, it's ETH and GASETH debt are transferred from the Active Pool to the liquidator.
 *
 */
contract ActivePool is Ownable, CheckContract, IActivePool {
    using SafeMath for uint256;

    string public constant NAME = "ActivePool";

    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    uint256 internal ETH; // deposited ether tracker
    uint256 internal GASETHDebt;

    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolGASETHDebtUpdated(uint256 _GASETHDebt);
    event ActivePoolETHBalanceUpdated(uint256 _ETH);

    // --- Contract setters ---

    function setAddresses(address _borrowerOperationsAddress, address _troveManagerAddress) external onlyOwner {
        checkContract(_borrowerOperationsAddress);
        checkContract(_troveManagerAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);

        _renounceOwnership();
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the ETH state variable.
    *
    *Not necessarily equal to the the contract's raw ETH balance - ether can be forcibly sent to contracts.
    */
    function getETH() external view override returns (uint256) {
        return ETH;
    }

    function getGASETHDebt() external view override returns (uint256) {
        return GASETHDebt;
    }

    // --- Pool functionality ---

    function sendETH(address _account, uint256 _amount) external override {
        _requireCallerIsBOorTroveM();
        ETH = ETH.sub(_amount);
        emit ActivePoolETHBalanceUpdated(ETH);
        emit EtherSent(_account, _amount);

        (bool success,) = _account.call{value: _amount}("");
        require(success, "ActivePool: sending ETH failed");
    }

    function increaseGASETHDebt(uint256 _amount) external override {
        _requireCallerIsBOorTroveM();
        GASETHDebt = GASETHDebt.add(_amount);
        ActivePoolGASETHDebtUpdated(GASETHDebt);
    }

    function decreaseGASETHDebt(uint256 _amount) external override {
        _requireCallerIsBOorTroveM();
        GASETHDebt = GASETHDebt.sub(_amount);
        ActivePoolGASETHDebtUpdated(GASETHDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "ActivePool: Caller is not BO");
    }

    function _requireCallerIsBOorTroveM() internal view {
        require(
            msg.sender == borrowerOperationsAddress || msg.sender == troveManagerAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager"
        );
    }

    function _requireCallerIsBOorTroveM() internal view {
        require(
            msg.sender == borrowerOperationsAddress || msg.sender == troveManagerAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager"
        );
    }

    // --- Fallback function ---

    receive() external payable {
        _requireCallerIsBorrowerOperations();
        ETH = ETH.add(msg.value);
        emit ActivePoolETHBalanceUpdated(ETH);
    }
}

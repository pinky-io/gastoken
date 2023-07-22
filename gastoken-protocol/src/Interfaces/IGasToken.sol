// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../Dependencies/IERC20.sol";
import "../Dependencies/IERC2612.sol";

interface IGasToken is IERC20, IERC2612 {
    // --- Events ---

    event TroveManagerAddressChanged(address _troveManagerAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);

    event GasTokenBalanceUpdated(address _user, uint256 _amount);

    // --- Functions ---

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount) external;
}

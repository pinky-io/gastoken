// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Common interface for the Pools.
interface IPool {
    // --- Events ---

    event ETHBalanceUpdated(uint256 _newBalance);
    event GASETHBalanceUpdated(uint256 _newBalance);
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event EtherSent(address _to, uint256 _amount);

    // --- Functions ---

    function getETH() external view returns (uint256);

    function getGASETHDebt() external view returns (uint256);

    function increaseGASETHDebt(uint256 _amount) external;

    function decreaseGASETHDebt(uint256 _amount) external;
}

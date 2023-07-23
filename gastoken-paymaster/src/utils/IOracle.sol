// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function latestResponse() external view returns (bytes memory);
}

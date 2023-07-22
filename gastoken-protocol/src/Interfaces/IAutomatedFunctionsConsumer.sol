// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IAutomatedFunctionsConsumer {
    function latestResponse() external returns (bytes memory);
}

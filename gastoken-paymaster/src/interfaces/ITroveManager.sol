// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ITroveManager {
    function redeemCollateral(
        uint256 _GASETHAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations
    ) external;
}

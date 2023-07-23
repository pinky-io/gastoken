pragma solidity 0.8.19;

interface IHintHelpers {
    function getRedemptionHints(uint256 _GASETHamount, uint256 _price, uint256 _maxIterations)
        external
        view
        returns (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedGASETHamount);
}

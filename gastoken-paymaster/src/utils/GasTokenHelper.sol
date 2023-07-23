// Based by Infinitism's TokenPaymaster: https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/samples/utils/UniswapHelper.sol
pragma solidity 0.8.19;

import {IGasToken} from "../interfaces/IGasToken.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IHintHelpers} from "../interfaces/IHintHelpers.sol";

abstract contract GasTokenHelper {
    uint256 private constant PRICE_DENOMINATOR = 1e26;

    ITroveManager public immutable troveManager;
    IHintHelpers public immutable hintHelpers;

    IGasToken public immutable token;

    constructor(address _token, address _troveManager, address _hintHelpers) {
        // _token.approve(address(troveManager), type(uint256).max);// no use, protocol will burn the token
        token = IGasToken(_token);
        troveManager = ITroveManager(_troveManager);
        hintHelpers = IHintHelpers(_hintHelpers);
    }

    function _maybeRedeemTokens(uint256 quote) internal returns (uint256) {
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 amountOutMin = tokenToWei(tokenBalance, quote);

        if (amountOutMin > 10 ** 16) {
            return RedeemTokens(tokenBalance, quote);
        } else {
            return 0;
        }
    }

    function tokenToWei(uint256 amount, uint256 price) public pure returns (uint256) {
        return amount * price / PRICE_DENOMINATOR;
    }

    function weiToToken(uint256 amount, uint256 price) public pure returns (uint256) {
        return amount * PRICE_DENOMINATOR / price;
    }

    function RedeemTokens(uint256 amountIn, uint256 price) internal returns (uint256 amountOut) {
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedGASETHamount) =
            hintHelpers.getRedemptionHints(amountIn, price, 1);

        uint256 balanceBefore = address(this).balance;
        troveManager.redeemCollateral(
            truncatedGASETHamount, firstRedemptionHint, address(0), address(0), partialRedemptionHintNICR, 1
        );
        uint256 balanceAfter = address(this).balance;

        return balanceAfter - balanceBefore;
    }
}

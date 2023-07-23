// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TokenPaymaster} from "../src/Paymaster.sol";
import "../src/utils/IOracle.sol";
import {OracleHelper} from "../src/Utils/OracleHelper.sol";

contract PaymasterTest is Test {
    struct TokenPaymasterConfig {
        /// @notice The price markup percentage applied to the token price (1e6 = 100%)
        uint256 priceMarkup;
        /// @notice Exchange tokens to native currency if the EntryPoint balance of this Paymaster falls below this value
        uint256 minEntryPointBalance;
        /// @notice Estimated gas cost for refunding tokens after the transaction is completed
        uint256 refundPostopCost;
        /// @notice Transactions are only valid as long as the cached price is not older than this value
        uint256 priceMaxAge;
    }

    address public owner;
    address public user;

    TokenPaymaster pm;

    function setUp() public {
        owner = address(this);
        user = makeAddr("User");

        TokenPaymasterConfig memory conf = TokenPaymasterConfig(1000000, 10, 100, 1);
        OracleHelper.OracleHelperConfig memory conf2 =
            OracleHelper.OracleHelperConfig(IOracle(address(0)), true, 1000000, 6000000);
        pm = new TokenPaymaster(address(0), conf, conf2, address(this));
    }

    function testTest() public {
        pm.test();
    }
}

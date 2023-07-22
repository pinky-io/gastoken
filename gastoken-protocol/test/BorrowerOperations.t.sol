// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {BorrowerOperations} from "../src/BorrowerOperations.sol";
import {TroveManager} from "../src/TroveManager.sol";
import {GasPool} from "../src/GasPool.sol";
import {PriceFeed} from "../src/PriceFeed.sol";
import {SortedTroves} from "../src/SortedTroves.sol";
import {GasToken} from "../src/GasToken.sol";
import {ActivePool} from "../src/ActivePool.sol";
import {HintHelpers} from "../src/HintHelpers.sol";

contract BorrowerOperationsTest is Test {
    BorrowerOperations public BO;
    TroveManager public TM;
    GasPool public GP;
    PriceFeed public PF;
    SortedTroves public ST;
    ActivePool public AP;
    GasToken public GT;
    HintHelpers public HH;

    address public owner;
    address public user;
    address public redeemer;

    function setUp() public {
        owner = address(this);
        user = makeAddr("User");
        redeemer = makeAddr("Redeemer");

        BO = new BorrowerOperations();
        TM = new TroveManager();
        GP = new GasPool();
        PF = new PriceFeed();
        ST = new SortedTroves();
        AP = new ActivePool();
        GT = new GasToken(address(TM), address(BO));
        HH = new HintHelpers();

        hoax(owner);
        BO.setAddresses(address(TM), address(AP), address(GP), address(PF), address(ST), address(GT));
        hoax(owner);
        TM.setAddresses(address(BO), address(AP), address(GP), address(PF), address(GT), address(ST));
        ST.setParams(type(uint32).max, address(TM), address(BO));
        AP.setAddresses(address(BO), address(TM));
        HH.setAddresses(address(ST), address(TM));
        // PF.setAddresses(address(0x4854405B3825f28Cb973b68CE883dF2bd776f32C));
    }

    function testOpenTrove() external {
        hoax(user);
        BO.openTrove{value: 1 ether}(1 ether / 2, address(0), address(0));
    }

    function testRedeemCollateral() external {
        hoax(user);
        BO.openTrove{value: 1 ether}(1 ether / 4, address(0), address(0));
        hoax(makeAddr("random"));
        BO.openTrove{value: 1 ether}(1 ether / 4, address(0), address(0));

        hoax(user);
        GT.transfer(redeemer, 1 ether / 8);

        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedGASETHamount) =
            HH.getRedemptionHints(1 ether / 8, 20 gwei / 1000, 0);
        hoax(redeemer);
        TM.redeemCollateral(
            truncatedGASETHamount, firstRedemptionHint, address(0), address(0), partialRedemptionHintNICR, 0
        );
    }

    function testCloseTrove() external {
        hoax(user);
        BO.openTrove{value: 1 ether}(1 ether / 2, address(0), address(0));
        hoax(redeemer);
        BO.openTrove{value: 1 ether}(1 ether / 2, address(0), address(0));

        hoax(user);
        BO.closeTrove();
    }
}

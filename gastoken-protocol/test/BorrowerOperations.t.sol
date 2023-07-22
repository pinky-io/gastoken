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

contract BorrowerOperationsTest is Test {
    BorrowerOperations public BO;
    TroveManager public TM;
    GasPool public GP;
    PriceFeed public PF;
    SortedTroves public ST;
    ActivePool public AP;
    GasToken public GT;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = makeAddr("User");

        BO = new BorrowerOperations();
        TM = new TroveManager();
        GP = new GasPool();
        PF = new PriceFeed();
        ST = new SortedTroves();
        AP = new ActivePool();
        GT = new GasToken(address(TM), address(BO));

        hoax(owner);
        BO.setAddresses(address(TM), address(AP), address(GP), address(PF), address(ST), address(GT));
        hoax(owner);
        TM.setAddresses(address(BO), address(AP), address(GP), address(PF), address(GT), address(ST));
        // PF.setAddresses(address(0));//will fail if 0
    }

    function testOpenTrove() external {
        hoax(user);
        BO.openTrove{value: 1 ether}(500000000 gwei, address(0), address(0));
    }
}

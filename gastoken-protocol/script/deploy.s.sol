// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {BorrowerOperations} from "../src/BorrowerOperations.sol";
import {TroveManager} from "../src/TroveManager.sol";
import {GasPool} from "../src/GasPool.sol";
import {PriceFeed} from "../src/PriceFeed.sol";
import {SortedTroves} from "../src/SortedTroves.sol";
import {GasToken} from "../src/GasToken.sol";
import {ActivePool} from "../src/ActivePool.sol";
import {HintHelpers} from "../src/HintHelpers.sol";

contract Deploy is Script {
    BorrowerOperations public BO;
    TroveManager public TM;
    GasPool public GP;
    PriceFeed public PF;
    SortedTroves public ST;
    ActivePool public AP;
    GasToken public GT;
    HintHelpers public HH;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        BO = new BorrowerOperations();
        TM = new TroveManager();
        GP = new GasPool();
        PF = new PriceFeed();
        ST = new SortedTroves();
        AP = new ActivePool();
        GT = new GasToken(address(TM), address(BO));
        HH = new HintHelpers();

        BO.setAddresses(address(TM), address(AP), address(GP), address(PF), address(ST), address(GT));
        TM.setAddresses(address(BO), address(AP), address(GP), address(PF), address(GT), address(ST));
        ST.setParams(type(uint32).max, address(TM), address(BO));
        AP.setAddresses(address(BO), address(TM));
        HH.setAddresses(address(ST), address(TM));
        PF.setAddresses(address(0x4854405B3825f28Cb973b68CE883dF2bd776f32C));

        vm.stopBroadcast();
    }
}

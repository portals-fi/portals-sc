// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { CurveNGPortal } from "../../../src/curve/CurveNGPortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract CurveNGPortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Base";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        CurveNGPortal curveNGPortal =
            new CurveNGPortal(addresses.get(network, "admin"));
        console2.log(
            "Deployed CurveNGPortal at", address(curveNGPortal)
        );

        vm.stopBroadcast();
    }
}

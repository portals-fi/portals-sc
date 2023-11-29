// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { SolidlyPortal } from "../../../src/solidly/SolidlyPortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract SolidlyPortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Base";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        SolidlyPortal solidlyPortal =
            new SolidlyPortal(addresses.get(network, "admin"));
        console2.log("Deployed", address(solidlyPortal));

        vm.stopBroadcast();
    }
}

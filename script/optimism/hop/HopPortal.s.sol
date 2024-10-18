// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { HopPortal } from "../../../src/hop/HopPortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract HopPortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Optimism";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        HopPortal hopPortal =
            new HopPortal(addresses.get(network, "admin"));
        console2.log("Deployed HopPortal at", address(hopPortal));

        vm.stopBroadcast();
    }
}

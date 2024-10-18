// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { GammaPortal } from "../../../src/gamma/GammaPortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract GammaPortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Arbitrum";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        GammaPortal gammaPortal =
            new GammaPortal(addresses.get(network, "admin"));
        console2.log("Deployed GammaPortal at", address(gammaPortal));

        vm.stopBroadcast();
    }
}

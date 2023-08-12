// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { VelodromeV2Portal } from
    "../../../src/velodrome/VelodromeV2Portal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract VelodromeV2PortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Optimism";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        VelodromeV2Portal velodromeV2Portal =
            new VelodromeV2Portal(addresses.get(network, "admin"));
        console2.log("Deployed", address(velodromeV2Portal));

        vm.stopBroadcast();
    }
}

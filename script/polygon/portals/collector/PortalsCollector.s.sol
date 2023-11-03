// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { PortalsCollector } from
    "../../../../src/portals/collector/PortalsCollectorFlat.sol";

import { Addresses } from "../../../constants/Addresses.sol";

contract PortalsCollectorDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Polygon";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        PortalsCollector collector =
            new PortalsCollector(addresses.get(network, "admin"));

        console2.log(
            "Deployed PortalsCollector at", address(collector)
        );

        vm.stopBroadcast();
    }
}

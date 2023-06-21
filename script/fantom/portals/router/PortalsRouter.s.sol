// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { PortalsMulticall } from
    "../../../../src/portals/multicall/PortalsMulticall.sol";
import { PortalsRouter } from
    "../../../../src/portals/router/PortalsRouter.sol";

import { Addresses } from "../../../constants/Addresses.sol";

contract PortalsRouterDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Fantom";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        PortalsMulticall multicall = new PortalsMulticall();
        console2.log(
            "Deployed PortalsMulticall at", address(multicall)
        );

        PortalsRouter router =
        new PortalsRouter(addresses.get(network, "admin"), address(multicall));

        console2.log("Deployed PortalsRouter at", address(router));

        vm.stopBroadcast();
    }
}

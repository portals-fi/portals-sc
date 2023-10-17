// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { BalancerV2BoostedPortal } from
    "../../../src/balancer/BalancerV2BoostedPortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract BalancerV2BoostedPortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Optimism";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        BalancerV2BoostedPortal portal =
        new BalancerV2BoostedPortal(addresses.get(network, "admin"));
        console2.log(
            "Deployed BalancerV2BoostedPortal at", address(portal)
        );

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { BalancerGyroscopePortal } from
    "../../../src/balancer/BalancerGyroscopePortal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract BalancerGyroscopePortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Arbitrum";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        BalancerGyroscopePortal balancerGyroscopePortal = new BalancerGyroscopePortal(
            addresses.get(network, "admin")
        );
        console2.log(
            "Deployed BalancerGyroscopePortal at",
            address(balancerGyroscopePortal)
        );

        vm.stopBroadcast();
    }
}

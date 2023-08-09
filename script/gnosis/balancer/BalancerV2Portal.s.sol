// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { BalancerV2Portal } from
    "../../../src/balancer/BalancerV2Portal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract BalancerV2PortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Gnosis";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        BalancerV2Portal balancerV2Portal =
            new BalancerV2Portal(addresses.get(network, "admin"));
        console2.log(
            "Deployed BalancerV2Portal at", address(balancerV2Portal)
        );

        vm.stopBroadcast();
    }
}

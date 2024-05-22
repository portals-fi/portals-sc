// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { CamelotV2Portal } from
    "../../../src/uniswap/CamelotV2Portal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract CamelotV2PortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Arbitrum";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        CamelotV2Portal camelotV2Portal =
            new CamelotV2Portal(addresses.get(network, "admin"));
        console2.log(
            "Deployed CamelotV2Portal at", address(camelotV2Portal)
        );

        vm.stopBroadcast();
    }
}

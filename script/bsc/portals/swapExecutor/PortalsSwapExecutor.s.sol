// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { PortalsSwapExecutor } from
    "../../../../src/portals/swapExecutor/PortalsSwapExecutor.sol";

import { Addresses } from "../../../constants/Addresses.sol";

contract PortalsSwapExecutorDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "BSC";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        PortalsSwapExecutor executor =
            new PortalsSwapExecutor(addresses.get(network, "admin"));
        console2.log(
            "Deployed PortalsSwapExecutor at", address(executor)
        );

        vm.stopBroadcast();
    }
}

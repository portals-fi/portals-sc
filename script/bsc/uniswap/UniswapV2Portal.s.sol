// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { UniswapV2Portal } from
    "../../../src/uniswap/UniswapV2Portal.sol";

import { Addresses } from "../../constants/Addresses.sol";

contract UniswapV2PortalDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "BSC";

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        UniswapV2Portal uniswapV2Portal =
            new UniswapV2Portal(addresses.get(network, "admin"));
        console2.log(
            "Deployed UniswapV2Portal at", address(uniswapV2Portal)
        );

        vm.stopBroadcast();
    }
}

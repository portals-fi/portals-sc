// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { PortalsQuoter } from
    "../../../../src/portals/quoter/PortalsQuoter.sol";

import { Addresses } from "../../../constants/Addresses.sol";

contract PortalsQuoterDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        PortalsQuoter quoter = new PortalsQuoter();
        console2.log("Deployed PortalsQuoter at", address(quoter));

        vm.stopBroadcast();
    }
}

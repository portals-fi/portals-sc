// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { GraphBootstrapper } from
    "../../../../src/portals/graph-bootstrapper/GraphBootstrapper.sol";
import { Addresses } from "../../../constants/Addresses.sol";

contract GraphBootstrapperDeployer is Script {
    Addresses addresses = new Addresses();

    function run() external {
        string memory network = "Avalanche";

        address[] memory devs = new address[](3);

        devs[0] = 0x4689CFF824d63117F9C4C42F3EC0001676F00d25;
        devs[1] = 0x3dc27165F9329AFe2D0EB89dD8ED70FCb7473472;
        devs[2] = 0xC6d7148287C3fD606c15e6778626494c9B474cfB;

        string memory deployerMnemonic = vm.envString("MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(deployerMnemonic, 0);
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address", vm.addr(deployerPrivateKey));

        GraphBootstrapper graphBootstrapper =
        new GraphBootstrapper(addresses.get(network, "admin"), devs);
        console2.log(
            "Deployed GraphBootstrapper at",
            address(graphBootstrapper)
        );

        vm.stopBroadcast();
    }
}

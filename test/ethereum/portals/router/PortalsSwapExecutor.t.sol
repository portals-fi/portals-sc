/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests the portal function from PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { PortalsSwapExecutor } from
    "../../../../src/portals/swapExecutor/PortalsSwapExecutor.sol";
import { IUniswapV3Router } from
    "../../../../src/portals/swapExecutor/interface/IUniswapV3Router.sol";
import { IBalancerV2Vault } from
    "../../../../src/portals/swapExecutor/interface/IBalancerV2Vault.sol";

contract PortalsSwapExecutorTest is Test {
    uint256 mainnetFork =
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

    uint256 internal ownerPrivateKey = 0xDAD;
    uint256 internal userPrivateKey = 0xB0B;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal user = vm.addr(userPrivateKey);

    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    //Balancer V2
    bytes32 DAI_WETH_POOL_ID =
        0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a;

    IUniswapV3Router uniswapRouter =
        IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IBalancerV2Vault balancerVault =
        IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    PortalsSwapExecutor public executor =
        new PortalsSwapExecutor(owner);

    function setUp() public {
        startHoax(user);
    }

    function testSwapUniswapV3Single() public {
        uint256 inputAmount = 10 ether;
        uint24 fee = 3000;
        deal(address(WETH), user, inputAmount);

        ERC20(WETH).approve(address(executor), inputAmount);

        executor.swapUniswapV3Single(
            WETH, inputAmount, DAI, fee, uniswapRouter, user
        );

        uint256 daiBalance = ERC20(DAI).balanceOf(user);
        assertTrue(daiBalance > 0);
    }

    function testSwapUniswapV3Multi() public {
        uint256 inputAmount = 10 ether;
        uint24 fee = 3000;
        deal(address(WETH), user, inputAmount);

        bytes memory path = abi.encodePacked(address(WETH), fee, DAI);

        ERC20(WETH).approve(address(executor), inputAmount);

        executor.swapUniswapV3Multi(
            WETH, inputAmount, path, uniswapRouter, address(user)
        );

        uint256 daiBalance = ERC20(DAI).balanceOf(user);
        assertTrue(daiBalance > 0);
    }

    function testSwapBalancerV2Single() public {
        uint256 inputAmount = 10 ether;
        deal(address(WETH), user, inputAmount);

        ERC20(WETH).approve(address(executor), inputAmount);

        executor.swapBalancerV2Single(
            WETH,
            inputAmount,
            DAI,
            DAI_WETH_POOL_ID,
            balancerVault,
            payable(address(user))
        );

        uint256 daiBalance = ERC20(DAI).balanceOf(user);
        assertTrue(daiBalance > 0);
    }

    function testSwapBalancerV2Multi() public {
        uint256 inputAmount = 10 ether;
        deal(address(WETH), user, inputAmount);

        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;

        // Define the swap steps using a real pool
        IBalancerV2Vault.BatchSwapStep[] memory swaps =
            new IBalancerV2Vault.BatchSwapStep[](1);
        swaps[0] = IBalancerV2Vault.BatchSwapStep({
            poolId: DAI_WETH_POOL_ID,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: inputAmount,
            userData: ""
        });

        int256[] memory limits = new int256[](2);

        ERC20(WETH).approve(address(executor), inputAmount);

        uint256 outputAmount = executor.swapBalancerV2Multi(
            assets,
            inputAmount,
            swaps,
            limits,
            balancerVault,
            payable(address(this))
        );

        assertTrue(outputAmount > 0, "Expected non-zero DAI amount");
    }
}

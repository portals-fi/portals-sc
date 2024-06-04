/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2024 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PoolsidePortal.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { PoolsidePortal } from
    "../../../src/uniswap/PoolsidePortal.sol";
import { IBasicButtonswapRouter } from
    "../../../src/uniswap/interface/IBasicButtonswapRouter.sol";

import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract UniswapV2PortalTest is Test {
    uint256 mainnetFork =
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

    uint256 internal ownerPrivateKey = 0xDAD;
    uint256 internal userPrivateKey = 0xB0B;
    uint256 internal collectorPivateKey = 0xA11CE;
    uint256 internal adversaryPivateKey = 0xC0C;
    uint256 internal partnerPivateKey = 0xABE;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal user = vm.addr(userPrivateKey);
    address internal collector = vm.addr(collectorPivateKey);
    address internal adversary = vm.addr(adversaryPivateKey);
    address internal partner = vm.addr(partnerPivateKey);

    address internal stETH =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal ETH = address(0);
    address internal stETH_WETH =
        0x235b25f9f56B39eFD8293C0d2A9Ee70719E25B85;
    IBasicButtonswapRouter internal poolsideRouter =
    IBasicButtonswapRouter(0x6CF6ac4712fE64cDa8138009B042B36e80f072bE);

    uint256 internal constant UNISWAP_FEE = 30; // 30 BPS

    Addresses public addresses = new Addresses();

    PoolsidePortal public poolsidePortal =
        new PoolsidePortal(addresses.get("Ethereum", "admin"));

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_Poolside_stETH_WETH_with_WETH() public {
        address inputToken = WETH;
        uint256 inputAmount = 5 ether;

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address outputToken = stETH_WETH;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(poolsidePortal), inputAmount
        );

        poolsidePortal.portalIn{ value: 0 }(
            inputToken,
            inputAmount,
            outputToken,
            poolsideRouter,
            UNISWAP_FEE,
            1000,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!poolsidePortal.paused());
        poolsidePortal.pause();
        assertTrue(poolsidePortal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(poolsidePortal.paused());
        poolsidePortal.pause();
        assertTrue(poolsidePortal.paused());
        poolsidePortal.unpause();
        assertFalse(poolsidePortal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!poolsidePortal.paused());
        poolsidePortal.pause();
        assertTrue(poolsidePortal.paused());
        test_PortalIn_Poolside_stETH_WETH_with_WETH();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!poolsidePortal.paused());
        poolsidePortal.pause();
    }
}

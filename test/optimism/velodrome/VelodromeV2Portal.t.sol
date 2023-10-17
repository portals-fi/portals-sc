/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { PortalsRouter } from
    "../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../src/portals/multicall/PortalsMulticall.sol";
import { VelodromeV2Portal } from
    "../../../src/velodrome/VelodromeV2Portal.sol";
import { IVelodromeV2Router02 } from
    "../../../src/velodrome/interface/IVelodromeV2Router02.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract VelodromeV2PortalTest is Test {
    uint256 optimismFork =
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));

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

    address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address internal DOLA = 0x8aE125E8653821E851F12A49F7765db9a9ce7384;
    address internal WETH = 0x4200000000000000000000000000000000000006;
    address internal ETH = address(0);
    address internal USDC_DOLA =
        0xB720FBC32d60BB6dcc955Be86b98D8fD3c4bA645;
    address internal WETH_USDC =
        0x0493Bf8b6DBB159Ce2Db2E0E8403E753Abd1235b;
    IVelodromeV2Router02 internal VelodromeV2Router =
    IVelodromeV2Router02(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    VelodromeV2Portal public velodromeV2Portal =
        new VelodromeV2Portal(owner);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_VelodromeV2_StableV2_USDC_DOLA_Direct()
        public
    {
        address tokenA = USDC;
        address tokenB = DOLA;

        uint256 amountA = 5_000_000_000; // 5000 USDC
        uint256 amountB = 6_325_280_000_000_000_000_000; // 6325.28 DOLA

        deal(address(tokenA), user, amountA);
        deal(address(tokenB), user, amountB);

        assertEq(ERC20(tokenA).balanceOf(user), amountA);
        assertEq(ERC20(tokenB).balanceOf(user), amountB);

        uint256 value = 0;

        address outputToken = USDC_DOLA;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(tokenA).transfer(address(velodromeV2Portal), amountA);
        ERC20(tokenB).transfer(address(velodromeV2Portal), amountB);

        velodromeV2Portal.portalIn{ value: value }(
            tokenA, tokenB, VelodromeV2Router, true, user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_VelodromeV2_VolatileV2_WETH_USDC_Direct()
        public
    {
        address tokenA = WETH;
        address tokenB = USDC;

        uint256 amountA = 50 ether; // 5000 WETH
        uint256 amountB = 92_496_000_000; // 92,496 USDC

        deal(address(tokenA), user, amountA);
        deal(address(tokenB), user, amountB);

        assertEq(ERC20(tokenA).balanceOf(user), amountA);
        assertEq(ERC20(tokenB).balanceOf(user), amountB);

        uint256 value = 0;

        address outputToken = WETH_USDC;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(tokenA).transfer(address(velodromeV2Portal), amountA);
        ERC20(tokenB).transfer(address(velodromeV2Portal), amountB);

        velodromeV2Portal.portalIn{ value: value }(
            tokenA, tokenB, VelodromeV2Router, false, user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!velodromeV2Portal.paused());
        velodromeV2Portal.pause();
        assertTrue(velodromeV2Portal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(velodromeV2Portal.paused());
        velodromeV2Portal.pause();
        assertTrue(velodromeV2Portal.paused());
        velodromeV2Portal.unpause();
        assertFalse(velodromeV2Portal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!velodromeV2Portal.paused());
        velodromeV2Portal.pause();
        assertTrue(velodromeV2Portal.paused());
        test_PortalIn_VelodromeV2_StableV2_USDC_DOLA_Direct();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!velodromeV2Portal.paused());
        velodromeV2Portal.pause();
    }
}

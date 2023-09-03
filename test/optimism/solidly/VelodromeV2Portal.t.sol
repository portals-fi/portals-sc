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
import { SolidlyPortal } from
    "../../../src/velodrome/SolidlyPortal.sol";
import { ISolidlyRouter } from
    "../../../src/velodrome/interface/ISolidlyRouter.sol";
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
    uint256 fork =
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
    address internal MAI = 0xdFA46478F9e5EA86d57387849598dbFB2e964b02;
    address internal DOLA = 0x8aE125E8653821E851F12A49F7765db9a9ce7384;
    address internal WETH = 0x4200000000000000000000000000000000000006;
    address internal ETH = address(0);
    address internal USDC_DOLA =
        0xB720FBC32d60BB6dcc955Be86b98D8fD3c4bA645;
    address internal WETH_USDC =
        0x0493Bf8b6DBB159Ce2Db2E0E8403E753Abd1235b;
        address internal USDC_MAI = 0xE54e4020d1C3afDB312095D90054103E68fe34B0;
    ISolidlyRouter internal velodromeV2Router =
    ISolidlyRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    SolidlyPortal public solidlyPortal =
        new SolidlyPortal(owner);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_VelodromeV2_VolatileV2_WETH_USDC_Direct_with_WETH(
    ) public {
        address inputToken = WETH;

        uint256 inputAmount = 50 ether; // ~$80,000 ETH

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = WETH_USDC;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            false,
            30,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

        function test_PortalIn_VelodromeV2_VolatileV2_WETH_USDC_Direct_with_USDC(
    ) public {
        address inputToken = USDC;

        uint256 inputAmount = 80_000_000_000; // 80000 USDC

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = WETH_USDC;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            false,
            30,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_VelodromeV2_StableV2_USDC_DOLA_Direct_with_USDC(
    ) public {
        address inputToken = USDC;

        uint256 inputAmount = 80_000_000_000; // 80000 USDC

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = USDC_DOLA;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            true,
            5,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_VelodromeV2_StableV2_USDC_DOLA_Direct_with_DOLA(
    ) public {
        address inputToken = DOLA;

        uint256 inputAmount = 80_000 ether; // 80000 DOLA

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = USDC_DOLA;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            true,
            5,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_VelodromeV2_StableV2_USDC_MAI_Direct_with_MAI(
    ) public {
        address inputToken = MAI;

        uint256 inputAmount = 80_000 ether; // 80000 sUSD

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = USDC_MAI;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            true,
            5,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

        function test_PortalIn_VelodromeV2_StableV2_USDC_MAI_Direct_with_USDC(
    ) public {
        address inputToken = USDC;

        uint256 inputAmount = 80_000_000_000; // 80000 USDC

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = USDC_MAI;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(
            address(solidlyPortal), inputAmount
        );

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            outputToken,
            velodromeV2Router,
            true,
            true,
            5,
            user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    // function test_Pausable() public {
    //     changePrank(owner);
    //     assertTrue(!solidlyPortal.paused());
    //     solidlyPortal.pause();
    //     assertTrue(solidlyPortal.paused());
    // }

    // function test_UnPausable() public {
    //     changePrank(owner);
    //     assertFalse(solidlyPortal.paused());
    //     solidlyPortal.pause();
    //     assertTrue(solidlyPortal.paused());
    //     solidlyPortal.unpause();
    //     assertFalse(solidlyPortal.paused());
    // }

    // function testFail_Portal_Reverts_When_Paused() public {
    //     changePrank(owner);
    //     assertTrue(!solidlyPortal.paused());
    //     solidlyPortal.pause();
    //     assertTrue(solidlyPortal.paused());
    //     test_PortalIn_VelodromeV2_StableV2_USDC_DOLA_Direct_with_DOLA();
    // }

    // function testFail_Pausable_by_Admin_Only() public {
    //     assertTrue(!solidlyPortal.paused());
    //     solidlyPortal.pause();
    // }
}

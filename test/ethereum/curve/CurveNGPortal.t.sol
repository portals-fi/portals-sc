/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { CurveNGPortal } from "../../../src/curve/CurveNGPortal.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console.sol";

contract CurveNGPortalTest is Test {
    uint256 ethereumFork =
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

    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address internal CURVE_USDe_USDC_POOL =
        0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72;

    Addresses public addresses = new Addresses();

    CurveNGPortal public curveNGPortal = new CurveNGPortal(owner);

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_USDCe_Pool_with_USDC_Direct() public {
        address token = USDC;
        address pool = CURVE_USDe_USDC_POOL;
        address outputToken = CURVE_USDe_USDC_POOL;
        uint256 index = 1;
        uint256 amount = 50_000_000_000; // 50,000 USDC

        deal(address(token), user, amount);

        assertEq(ERC20(token).balanceOf(user), amount);

        uint256 value = 0;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(token).approve(address(curveNGPortal), amount);

        curveNGPortal.portalIn{ value: value }(
            token, amount, index, pool, user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_USDCe_Pool_with_USDCe_Direct() public {
        address token = USDe;
        address pool = CURVE_USDe_USDC_POOL;
        address outputToken = CURVE_USDe_USDC_POOL;
        uint256 index = 0;
        uint256 amount = 50_000 ether; // 50,000 USDe

        deal(address(token), user, amount);

        assertEq(ERC20(token).balanceOf(user), amount);

        uint256 value = 0;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(token).approve(address(curveNGPortal), amount);

        curveNGPortal.portalIn{ value: value }(
            token, amount, index, pool, user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!curveNGPortal.paused());
        curveNGPortal.pause();
        assertTrue(curveNGPortal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(curveNGPortal.paused());
        curveNGPortal.pause();
        assertTrue(curveNGPortal.paused());
        curveNGPortal.unpause();
        assertFalse(curveNGPortal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!curveNGPortal.paused());
        curveNGPortal.pause();
        assertTrue(curveNGPortal.paused());
        test_PortalIn_USDCe_Pool_with_USDC_Direct();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!curveNGPortal.paused());
        curveNGPortal.pause();
    }
}

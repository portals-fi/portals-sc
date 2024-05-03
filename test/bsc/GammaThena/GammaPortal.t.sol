/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { GammaPortal } from "../../../src/gamma/GammaPortal.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract GammaPortalTest is Test {
    uint256 bscFork = vm.createSelectFork(vm.envString("BSC_RPC_URL"));

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

    address internal WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal PEG_ETH =
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address internal ETH = address(0);

    address internal GAMMA_PROXY =
        0xF75c017E3b023a593505e281b565ED35Cc120efa;

    address internal GAMMA_POOL =
        0x10bf6e7B28b1cfFb1c047D7F815953931e5Ee947;

    Addresses public addresses = new Addresses();

    GammaPortal public gammaPortal = new GammaPortal(owner);

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_UseFullTokenRandom() public {
        address proxy = GAMMA_PROXY;
        address token0 = PEG_ETH;
        address token1 = WBNB;
        address pool = GAMMA_POOL;
        address recipient = user;
        uint256 amount0 = 0.2 ether;
        uint256 amount1 = 1 ether;

        // Mimic sending Tokens to user for the purpose of this test
        deal(token0, recipient, amount0);
        deal(token1, recipient, amount1);

        // Check the initial WBNB balance of the user
        assertEq(ERC20(token0).balanceOf(recipient), amount0);
        assertEq(ERC20(token1).balanceOf(recipient), amount1);

        // Approve the amount to spend by the portal
        ERC20(token0).approve(address(gammaPortal), amount0);
        ERC20(token1).approve(address(gammaPortal), amount1);

        uint256 initialBalance = ERC20(pool).balanceOf(recipient);

        // Perform the portalIn operation
        gammaPortal.portalIn(proxy, token0, token1, pool, recipient);

        uint256 finalBalance = ERC20(pool).balanceOf(recipient);

        uint256 finalBalanceToken0 =
            ERC20(token0).balanceOf(recipient);
        uint256 finalBalanceToken1 =
            ERC20(token1).balanceOf(recipient);

        assertTrue(
            finalBalanceToken0 == 0 || finalBalanceToken1 == 0,
            "One of the tokens should be 0 after portalIn"
        );

        assertTrue(
            finalBalance > initialBalance,
            "Balance should be higher after portalIn"
        );
    }

    function test_PortalIn_UseFullToken0() public {
        address proxy = GAMMA_PROXY;
        address token0 = PEG_ETH;
        address token1 = WBNB;
        address pool = GAMMA_POOL;
        address recipient = user;
        uint256 amount0 = 1 ether;
        uint256 amount1 = 10 ether;

        // Mimic sending Tokens to user for the purpose of this test
        deal(token0, recipient, amount0);
        deal(token1, recipient, amount1);

        // Check the initial WBNB balance of the user
        assertEq(ERC20(token0).balanceOf(recipient), amount0);
        assertEq(ERC20(token1).balanceOf(recipient), amount1);

        // Approve the amount to spend by the portal
        ERC20(token0).approve(address(gammaPortal), amount0);
        ERC20(token1).approve(address(gammaPortal), amount1);

        uint256 initialBalance = ERC20(pool).balanceOf(recipient);

        // Perform the portalIn operation
        gammaPortal.portalIn(proxy, token0, token1, pool, recipient);

        uint256 finalBalance = ERC20(pool).balanceOf(recipient);

        assertEq(ERC20(token0).balanceOf(recipient), 0);

        assertTrue(
            finalBalance > initialBalance,
            "Balance should be higher after portalIn"
        );
    }

    function test_PortalIn_UseFullToken1() public {
        address proxy = GAMMA_PROXY;
        address token0 = PEG_ETH;
        address token1 = WBNB;
        address pool = GAMMA_POOL;
        address recipient = user;
        uint256 amount = 5 ether;

        // Mimic sending Tokens to user for the purpose of this test
        deal(token0, recipient, amount);
        deal(token1, recipient, amount);

        // Check the initial WBNB balance of the user
        assertEq(ERC20(token0).balanceOf(recipient), amount);
        assertEq(ERC20(token1).balanceOf(recipient), amount);

        // Approve the amount to spend by the portal
        ERC20(token0).approve(address(gammaPortal), amount);
        ERC20(token1).approve(address(gammaPortal), amount);

        uint256 initialBalance = ERC20(pool).balanceOf(recipient);

        // Perform the portalIn operation
        gammaPortal.portalIn(proxy, token0, token1, pool, recipient);

        uint256 finalBalance = ERC20(pool).balanceOf(recipient);

        assertEq(ERC20(token1).balanceOf(recipient), 0);

        assertTrue(
            finalBalance > initialBalance,
            "Balance should be higher after portalIn"
        );
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!gammaPortal.paused());
        gammaPortal.pause();
        assertTrue(gammaPortal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(gammaPortal.paused());
        gammaPortal.pause();
        assertTrue(gammaPortal.paused());
        gammaPortal.unpause();
        assertFalse(gammaPortal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!gammaPortal.paused());
        gammaPortal.pause();
        assertTrue(gammaPortal.paused());
        test_PortalIn_UseFullToken1();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!gammaPortal.paused());
        gammaPortal.pause();
    }
}

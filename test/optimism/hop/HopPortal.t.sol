/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { HopPortal } from "../../../src/hop/HopPortal.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract HopPortalTest is Test {
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
    address internal WETH = 0x4200000000000000000000000000000000000006;
    address internal ETH = address(0);

    address internal HOP_ETH_POOL =
        0xaa30D6bba6285d0585722e2440Ff89E23EF68864;

    address internal HOP_ETH_LP_TOKEN =
        0x5C2048094bAaDe483D0b1DA85c3Da6200A88a849;

    Addresses public addresses = new Addresses();

    HopPortal public hopPortal = new HopPortal(owner);

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_ETH_Pool_with_WETH_Direct() public {
        address token = WETH;
        address pool = HOP_ETH_POOL;
        address outputToken = HOP_ETH_LP_TOKEN;
        uint256 index = 0;
        uint256 amount = 5 ether;

        deal(address(token), user, amount);

        assertEq(ERC20(token).balanceOf(user), amount);

        uint256 value = 0;

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(WETH).approve(address(hopPortal), amount);

        hopPortal.portalIn{ value: value }(
            token, amount, index, outputToken, pool, user
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!hopPortal.paused());
        hopPortal.pause();
        assertTrue(hopPortal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(hopPortal.paused());
        hopPortal.pause();
        assertTrue(hopPortal.paused());
        hopPortal.unpause();
        assertFalse(hopPortal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!hopPortal.paused());
        hopPortal.pause();
        assertTrue(hopPortal.paused());
        test_PortalIn_ETH_Pool_with_WETH_Direct();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!hopPortal.paused());
        hopPortal.pause();
    }
}

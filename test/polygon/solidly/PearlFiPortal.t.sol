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
import { SolidlyPortal } from "../../../src/solidly/SolidlyPortal.sol";
import { ISolidlyRouter } from
    "../../../src/solidly/interface/ISolidlyRouter.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";
import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ISolidlyPortal } from
    "../../../src/solidly/interface/ISolidlyPortal.sol";
import { ISolidlyPool } from
    "../../../src/solidly/interface/ISolidlyPool.sol";

contract PearlFiPortalTest is Test {
    uint256 fork =
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

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

    address internal USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address internal MATIC = address(0);
    address internal USDC_USDR =
        0xD17cb0f162f133e339C0BbFc18c36c357E681D6b;

    ISolidlyRouter internal PearlFiRouter =
        ISolidlyRouter(0xcC25C0FD84737F44a7d38649b69491BBf0c7f083);

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    SolidlyPortal public solidlyPortal = new SolidlyPortal(owner);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_PearlFi_StableV1_USDC_USDR_Direct_with_USDC(
    ) public {
        address inputToken = USDC;

        uint256 inputAmount = 80_000_000_000; // 80000 USDC

        deal(address(inputToken), user, inputAmount);

        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        uint256 value = 0;

        address outputToken = USDC_USDR;

        ISolidlyPortal.SolidlyParams memory params = ISolidlyPortal
            .SolidlyParams(PearlFiRouter, false, true, 5, address(0));

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        ERC20(inputToken).approve(address(solidlyPortal), inputAmount);

        solidlyPortal.portalIn{ value: value }(
            inputToken,
            inputAmount,
            ISolidlyPool(outputToken),
            user,
            params
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!solidlyPortal.paused());
        solidlyPortal.pause();
        assertTrue(solidlyPortal.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(solidlyPortal.paused());
        solidlyPortal.pause();
        assertTrue(solidlyPortal.paused());
        solidlyPortal.unpause();
        assertFalse(solidlyPortal.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!solidlyPortal.paused());
        solidlyPortal.pause();
        assertTrue(solidlyPortal.paused());
        test_PortalIn_PearlFi_StableV1_USDC_USDR_Direct_with_USDC();
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!solidlyPortal.paused());
        solidlyPortal.pause();
    }
}

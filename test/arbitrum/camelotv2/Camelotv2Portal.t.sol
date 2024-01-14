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
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { CamelotV2Portal } from
    "../../../src/uniswap/CamelotV2Portal.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract CamelotV2PortalTest is Test {
    uint256 fork =
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

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

    address internal USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address internal WETH = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address internal PENDLE =
        0xBfCa4230115DE8341F3A3d5e8845fFb3337B2Be3;
    address internal ETH = address(0);
    address internal PENDLE_WETH =
        0xBfCa4230115DE8341F3A3d5e8845fFb3337B2Be3;
    address internal CamelotV2router =
        0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    uint256 internal constant UNISWAP_FEE = 4; // 4 BPS

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    CamelotV2Portal public camelotV2Portal =
        new CamelotV2Portal(addresses.get("Arbitrum", "admin"));

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_CamelotV2_PENDLE_WETH_With_ETH_Using_PENDLE_Intermediate(
    ) public {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = inputAmount;

        address intermediateToken = PENDLE;

        address outputToken = PENDLE_WETH;

        uint256 numCalls = 3;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            inputToken, inputAmount, intermediateToken, "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            inputToken, target, data, type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(camelotV2Portal),
                0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            address(camelotV2Portal),
            abi.encodeWithSignature(
                "portalIn(address,uint256,address,address,uint256,address)",
                intermediateToken,
                0,
                outputToken,
                CamelotV2router,
                UNISWAP_FEE,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    // function test_Pausable() public {
    //     changePrank(owner);
    //     assertTrue(!router.paused());
    //     router.pause();
    //     assertTrue(router.paused());
    // }

    // function test_UnPausable() public {
    //     changePrank(owner);
    //     assertFalse(router.paused());
    //     router.pause();
    //     assertTrue(router.paused());
    //     router.unpause();
    //     assertFalse(router.paused());
    // }

    // function testFail_Portal_Reverts_When_Paused() public {
    //     changePrank(owner);
    //     assertTrue(!router.paused());
    //     router.pause();
    //     assertTrue(router.paused());
    //     test_PortalIn_CamelotV2_PENDLE_WETH_With_ETH_Using_PENDLE_Intermediate(
    //     );
    // }

    // function testFail_Pausable_by_Admin_Only() public {
    //     assertTrue(!router.paused());
    //     router.pause();
    // }
}

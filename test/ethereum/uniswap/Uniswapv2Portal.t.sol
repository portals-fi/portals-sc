/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PortalsRouter } from
    "../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../src/portals/multicall/PortalsMulticall.sol";
import { UniswapV2Portal } from
    "../../../src/uniswap/UniswapV2Portal.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
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

    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal ETH = address(0);
    address internal USDC_WETH =
        0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address internal UniswapV2router =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router =
        new PortalsRouter(owner, collector, address(multicall));

    Addresses public addresses = new Addresses();

    UniswapV2Portal public uniswapV2Portal =
        new UniswapV2Portal(addresses.get("Ethereum", "admin"));

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_UniswapV2_USDC_WETH_With_ETH_Using_USDC_Intermediate(
    ) public {
        address sellToken = address(0);
        uint256 sellAmount = 5 ether;
        uint256 value = sellAmount;

        address intermediateToken = USDC;

        address buyToken = USDC_WETH;

        uint256 numCalls = 3;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: buyToken,
            minBuyAmount: 1,
            feeToken: sellToken,
            fee: 0,
            recipient: user,
            partner: partner
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            sellToken, sellAmount, intermediateToken, "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            sellToken, target, data, type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(uniswapV2Portal),
                0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            address(uniswapV2Portal),
            abi.encodeWithSignature(
                "portalIn(address,uint256,address,address,address)",
                intermediateToken,
                0,
                buyToken,
                UniswapV2router,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_UniswapV2_USDC_WETH_With_USDC_Using_USDC_Intermediate(
    ) public {
        address sellToken = USDC;
        uint256 sellAmount = 5_000_000_000; // 5000 USDC
        uint256 value = 0;

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = USDC_WETH;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: buyToken,
            minBuyAmount: 1,
            feeToken: sellToken,
            fee: 0,
            recipient: user,
            partner: partner
        });

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(uniswapV2Portal),
                0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            address(uniswapV2Portal),
            abi.encodeWithSignature(
                "portalIn(address,uint256,address,address,address)",
                intermediateToken,
                sellAmount,
                buyToken,
                UniswapV2router,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertTrue(!router.paused());
        router.pause();
        assertTrue(router.paused());
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!router.paused());
        router.pause();
        assertTrue(router.paused());
        test_PortalIn_UniswapV2_USDC_WETH_With_ETH_Using_USDC_Intermediate(
        );
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!router.paused());
        router.pause();
    }
}

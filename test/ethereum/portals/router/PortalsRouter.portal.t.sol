/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests the portal function from PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { PortalsRouter } from
    "../../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../../src/portals/multicall/PortalsMulticall.sol";
import { IPortalsRouter } from
    "../../../../src/portals/router/interface/IPortalsRouter.sol";

import { IPortalsMulticall } from
    "../../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../../utils/Quote/Quote.sol";
import { IQuote } from "../../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../../utils/SigUtils.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IRouterBase } from
    "../../../../src/portals/router/interface/IRouterBase.sol";

contract PortalTest is Test {
    uint256 mainnetFork =
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

    uint256 internal ownerPrivateKey = 0xDAD;
    uint256 internal userPrivateKey = 0xB0B;
    uint256 internal collectorPivateKey = 0xA11CE;
    uint256 internal adversaryPivateKey = 0xC0C;
    uint256 internal partnerPivateKey = 0xC0FFEE;
    uint256 internal broadcasterPrivateKey = 0xBABE;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal user = vm.addr(userPrivateKey);
    address internal collector = vm.addr(collectorPivateKey);
    address internal adversary = vm.addr(adversaryPivateKey);
    address internal partner = vm.addr(partnerPivateKey);
    address internal broadcaster = vm.addr(broadcasterPrivateKey);

    uint256 fee = 15;

    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal ETH = address(0);
    address internal StargateUSDC =
        0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56;
    address internal StargateRouter =
        0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    bytes32 internal USDC_DOMAIN_SEPARATOR =
        0x06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335;
    bytes32 internal DAI_DOMAIN_SEPARATOR =
        0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate(
    ) public {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = inputAmount;

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

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
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
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

    function test_PortalOut_Stargate_SUSDC_To_ETH_With_USDC_Intermediate(
    ) public {
        test_PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate();
        // Constants
        address inputToken = StargateUSDC;
        uint256 inputAmount = ERC20(inputToken).balanceOf(user);
        uint256 value = 0;

        address intermediateToken = USDC;

        (, bytes memory returnData) = StargateUSDC.call{ value: 0 }(
            abi.encodeWithSignature(
                "amountLPtoLD(uint256)", inputAmount
            )
        );

        uint256 intermediateAmount = uint256(bytes32(returnData));

        address outputToken = ETH;

        uint16 poolId = 1;

        uint256 numCalls = 5;

        // Order
        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        // External quote
        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            intermediateToken, intermediateAmount, outputToken, "0.1"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        // Multicall
        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);
        calls[0] = IPortalsMulticall.Call(
            inputToken,
            inputToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            inputToken,
            StargateRouter,
            abi.encodeWithSignature(
                "instantRedeemLocal(uint16,uint256,address)",
                poolId,
                0,
                address(multicall)
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken, target, data, type(uint256).max
        );
        calls[4] = IPortalsMulticall.Call(
            ETH, address(user), "", type(uint256).max
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        // Test
        ERC20(inputToken).approve(address(router), type(uint256).max);

        uint256 initialBalance = user.balance;

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = user.balance;

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
    ) public {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC
        uint256 value = 0;

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(inputToken).approve(address(router), inputAmount);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Revert_When_0_Value_Sent_With_ETH() public {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = 0;

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

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
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        vm.expectRevert("PortalsRouter: Invalid msg.value");
        router.portal{ value: value }(orderPayload, partner);
    }

    function test_Revert_When_Non_Zero_ETH_Value_Sent_With_ERC20()
        public
    {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC
        uint256 value = 1 ether;

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(inputToken).approve(address(router), inputAmount);

        vm.expectRevert(
            "PortalsRouter: Invalid quantity or msg.value"
        );
        router.portal{ value: value }(orderPayload, partner);
    }

    function test_PortalIn_Stargate_SUSDC_From_DAI_With_USDC_Intermediate(
    ) public {
        address inputToken = DAI;
        uint256 inputAmount = 5000 ether;
        uint256 value = 0;

        deal(address(DAI), user, inputAmount);
        assertEq(ERC20(DAI).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

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
            inputToken,
            inputToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            inputToken, target, data, type(uint256).max
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(inputToken).approve(address(router), inputAmount);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function testFail_Revert_When_Slippage_is_High() public {
        address inputToken = DAI;
        uint256 inputAmount = 5000 ether;
        uint256 value = 0;

        deal(address(DAI), user, inputAmount);
        assertEq(ERC20(DAI).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: type(uint256).max,
            recipient: user
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            inputToken, inputAmount, intermediateToken, "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            inputToken,
            inputToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            inputToken, target, data, type(uint256).max
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(inputToken).approve(address(router), inputAmount);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Ensure_Native_Fee_is_Collected() public {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = inputAmount;

        address intermediateToken = USDC;

        address feeToken = inputToken;

        uint256 feeAmount = (inputAmount * fee) / 10_000;

        address outputToken = StargateUSDC;

        uint256 numCalls = 4;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            inputToken,
            inputAmount - feeAmount,
            intermediateToken,
            "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            feeToken,
            address(multicall),
            abi.encodeWithSignature(
                "transferEth(address,uint256)", collector, feeAmount
            ),
            type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            inputToken, target, data, type(uint256).max
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)", 1, 0, user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);
        uint256 initialBalanceCollector = collector.balance;

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);
        uint256 finalBalanceCollector = collector.balance;

        assertTrue(finalBalance > initialBalance);
        assertTrue(
            finalBalanceCollector - initialBalanceCollector
                == feeAmount
        );
    }
}

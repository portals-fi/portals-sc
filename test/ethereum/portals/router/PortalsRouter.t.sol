/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

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

contract PortalsRouterTest is Test {
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

    PortalsRouter public router =
        new PortalsRouter(owner, collector, address(multicall));

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate(
    ) public {
        address sellToken = address(0);
        uint256 sellAmount = 5 ether;
        uint256 value = sellAmount;

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

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

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalOut_Stargate_SUSDC_To_ETH_With_USDC_Intermediate(
    ) public {
        test_PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate();
        // Constants
        address sellToken = StargateUSDC;
        uint256 sellAmount = ERC20(sellToken).balanceOf(user);
        uint256 value = 0;

        address intermediateToken = USDC;

        (, bytes memory returnData) = StargateUSDC.call{ value: 0 }(
            abi.encodeWithSignature(
                "amountLPtoLD(uint256)", sellAmount
            )
        );

        uint256 intermediateAmount = uint256(bytes32(returnData));

        address buyToken = ETH;

        uint16 poolId = 1;

        uint256 numCalls = 5;

        // Order
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

        // External quote
        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            intermediateToken, intermediateAmount, buyToken, "0.1"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        // Multicall
        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);
        calls[0] = IPortalsMulticall.Call(
            sellToken,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken,
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
        ERC20(sellToken).approve(address(router), type(uint256).max);

        uint256 initialBalance = user.balance;

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = user.balance;

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
    ) public {
        address sellToken = USDC;
        uint256 sellAmount = 5_000_000_000; // 5000 USDC
        uint256 value = 0;

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

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

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalIn_Stargate_SUSDC_From_DAI_With_USDC_Intermediate(
    ) public {
        address sellToken = DAI;
        uint256 sellAmount = 5000 ether;
        uint256 value = 0;

        deal(address(DAI), user, sellAmount);
        assertEq(ERC20(DAI).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

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
            sellToken,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken, target, data, type(uint256).max
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

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{ value: value }(orderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalInWithPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
        uint32 sellAmount
    ) public {
        address sellToken = USDC;
        vm.assume(sellAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

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

        IPortalsRouter.PermitPayload memory permitPayload =
        createPermitPayload(
            sellToken, true, false, USDC_DOMAIN_SEPARATOR
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portalWithPermit(orderPayload, permitPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalInWithPermit_Stargate_SUSDC_From_DAI_With_USDC_Intermediate(
    ) public {
        address sellToken = DAI;
        uint256 sellAmount = 5000 ether;

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

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

        address target;
        bytes memory data;
        if (sellToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                sellToken, sellAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            sellToken,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken, target, data, type(uint256).max
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

        IPortalsRouter.PermitPayload memory permitPayload =
        createPermitPayload(
            sellToken, true, true, DAI_DOMAIN_SEPARATOR
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portalWithPermit(orderPayload, permitPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalInWithSignature_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
        uint32 sellAmount
    ) public {
        address sellToken = USDC;
        vm.assume(sellAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

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

        address target;
        bytes memory data;
        if (sellToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                sellToken, sellAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

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

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
            createSignedOrderPayload(order, router.DOMAIN_SEPARATOR());
        signedOrderPayload.calls = calls;

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignature(signedOrderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalInWithSignature_Stargate_SUSDC_From_WETH_With_USDC_Intermediate(
    ) public {
        address sellToken = WETH;
        uint256 sellAmount = 5 ether;

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

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

        address target;
        bytes memory data;
        if (sellToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                sellToken, sellAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            sellToken,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken, target, data, type(uint256).max
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

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
            createSignedOrderPayload(order, router.DOMAIN_SEPARATOR());
        signedOrderPayload.calls = calls;

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignature(signedOrderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_PortalInWithSignatureAndPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
    ) public {
        address sellToken = USDC;
        uint256 sellAmount = 5_000_000_000; // 5000 USDC

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

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

        address target;
        bytes memory data;
        if (sellToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                sellToken, sellAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

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

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
            createSignedOrderPayload(order, router.DOMAIN_SEPARATOR());
        signedOrderPayload.calls = calls;

        IPortalsRouter.PermitPayload memory permitPayload =
        createPermitPayload(
            sellToken, true, false, USDC_DOMAIN_SEPARATOR
        );

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignatureAndPermit(
            signedOrderPayload, permitPayload
        );

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Ensure_ERC20_Fee_is_Collected(uint32 sellAmount)
        public
    {
        address sellToken = USDC;
        vm.assume(sellAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(sellToken), user, sellAmount);
        assertEq(ERC20(sellToken).balanceOf(user), sellAmount);

        address intermediateToken = USDC;

        address feeToken = sellToken;

        uint256 feeAmount = (sellAmount * fee) / 10_000;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 3;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: buyToken,
            minBuyAmount: 1,
            feeToken: sellToken,
            fee: feeAmount,
            recipient: user,
            partner: partner
        });

        address target;
        bytes memory data;
        if (sellToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                sellToken, sellAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            feeToken,
            feeToken,
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                router.collector(),
                feeAmount
            ),
            type(uint256).max
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

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
            createSignedOrderPayload(order, router.DOMAIN_SEPARATOR());
        signedOrderPayload.calls = calls;

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignature(signedOrderPayload);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Ensure_Native_Fee_is_Collected() public {
        address sellToken = address(0);
        uint256 sellAmount = 5 ether;
        uint256 value = sellAmount;

        address intermediateToken = USDC;

        address feeToken = sellToken;

        uint256 feeAmount = (sellAmount * fee) / 10_000;

        address buyToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 4;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: buyToken,
            minBuyAmount: 1,
            feeToken: sellToken,
            fee: feeAmount,
            recipient: user,
            partner: partner
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            sellToken,
            sellAmount - feeAmount,
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
                "transferEth(address,uint256)",
                router.collector(),
                feeAmount
            ),
            type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken, target, data, type(uint256).max
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
        test_PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate();
        test_PortalInWithPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
            4_000_000_000
        );
        test_PortalInWithSignature_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
            4_000_000_000
        );
    }

    function testFail_Pausable_by_Admin_Only() public {
        changePrank(adversary);
        assertTrue(!router.paused());
        router.pause();
    }

    function createPermitPayload(
        address sellToken,
        bool splitSignature,
        bool daiPermit,
        bytes32 domainSeparator
    )
        public
        returns (IPortalsRouter.PermitPayload memory permitPayload)
    {
        SigUtils sigUtils = new SigUtils(domainSeparator);

        bytes32 digest;
        if (daiPermit) {
            SigUtils.DaiPermit memory _daiPermit = SigUtils.DaiPermit({
                holder: user,
                spender: address(router),
                nonce: ERC20(sellToken).nonces(user),
                expiry: type(uint256).max,
                allowed: true
            });
            digest = sigUtils.getDaiPermitTypedDataHash(_daiPermit);
        } else {
            SigUtils.Permit memory permit = SigUtils.Permit({
                owner: user,
                spender: address(router),
                value: type(uint256).max,
                nonce: ERC20(sellToken).nonces(user),
                deadline: type(uint256).max
            });

            digest = sigUtils.getPermitTypedDataHash(permit);
        }
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(userPrivateKey, digest);

        permitPayload = IPortalsRouter.PermitPayload({
            owner: user,
            amount: type(uint256).max,
            deadline: type(uint256).max,
            signature: abi.encodePacked(r, s, v),
            splitSignature: splitSignature,
            daiPermit: daiPermit
        });
    }

    function createSignedOrderPayload(
        IPortalsRouter.Order memory order,
        bytes32 domainSeparator
    )
        public
        returns (
            IPortalsRouter.SignedOrderPayload memory signedOrderPayload
        )
    {
        SigUtils sigUtils = new SigUtils(domainSeparator);

        IPortalsRouter.SignedOrder memory signedOrder = IPortalsRouter
            .SignedOrder({
            order: order,
            sender: user,
            deadline: type(uint32).max,
            nonce: router.nonces(user)
        });

        bytes32 digest =
            sigUtils.getSignedOrderTypedDataHash(signedOrder);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(userPrivateKey, digest);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](0);

        signedOrderPayload = IPortalsRouter.SignedOrderPayload({
            signedOrder: signedOrder,
            signature: abi.encodePacked(r, s, v),
            calls: calls
        });
    }
}

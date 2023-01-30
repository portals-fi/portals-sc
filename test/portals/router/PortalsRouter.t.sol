/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { PortalsRouter } from
    "../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../src/portals/router/PortalsMulticall.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";

import { IPortalsMulticall } from
    "../../../src/portals/router/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract PortalsRouterTest is Test {
    uint256 mainnetFork =
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    PortalsMulticall public multicall = new PortalsMulticall();
    PortalsRouter public router =
        new PortalsRouter(owner, 0, collector, address(multicall));
    Quote public quote = new Quote();

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

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address ETH = address(0);
    address StargateUSDC = 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56;
    address StargateRouter =
        0x8731d54E9D02c286767d56ac03e8037C07e01e98;

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
            sellToken, sellAmount, target, data, type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            0,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            0,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{value: value}(order, calls);

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

        (, bytes memory returnData) = StargateUSDC.call{value: 0}(
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
            fee: 0,
            recipient: user,
            partner: partner
        });

        // External quote
        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            intermediateToken, intermediateAmount, buyToken, "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        // Multicall
        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);
        calls[0] = IPortalsMulticall.Call(
            sellToken,
            0,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken,
            0,
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
            0,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken, 0, target, data, type(uint256).max
        );
        calls[4] = IPortalsMulticall.Call(
            ETH, 0, address(user), "", type(uint256).max
        );

        // Test
        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = user.balance;

        router.portal{value: value}(order, calls);

        uint256 finalBalance = user.balance;

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
            0,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", target, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken, sellAmount, target, data, type(uint256).max
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            0,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken,
            0,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        ERC20(sellToken).approve(address(router), sellAmount);

        uint256 initialBalance = ERC20(buyToken).balanceOf(user);

        router.portal{value: value}(order, calls);

        uint256 finalBalance = ERC20(buyToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }
}

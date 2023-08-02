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
import { BalancerV2BoostedPortal } from
    "../../../src/balancer/BalancerV2BoostedPortal.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract BalancerV2BoostedPortalTest is Test {
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
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal ETH = address(0);
    address internal bb_a_usd =
        0xfeBb0bbf162E64fb9D0dfe186E517d84C395f016;
    address internal bb_a_dai =
        0x6667c6fa9f2b3Fc1Cc8D85320b62703d938E4385;
    address internal bb_a_usdc =
        0xcbFA4532D8B2ade2C261D3DD5ef2A2284f792692;

    bytes32 internal bb_a_usdcPoolId =
        0xcbfa4532d8b2ade2c261d3dd5ef2a2284f7926920000000000000000000004fa;
    bytes32 internal bb_a_usdPoolId =
        0xfebb0bbf162e64fb9d0dfe186e517d84c395f016000000000000000000000502;
    bytes32 internal bb_a_daiPoolId =
        0x6667c6fa9f2b3fc1cc8d85320b62703d938e43850000000000000000000004fb;

    address internal BalancerV2Vault =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    BalancerV2BoostedPortal public balancerV2BoostedPortal =
        new BalancerV2BoostedPortal(owner);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_BalancerV2Boosted_bb_a_USD_with_ETH_with_DAI_Intermediate(
    ) public {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = inputAmount;

        address intermediateToken = DAI;

        address outputToken = bb_a_usd;

        uint256 numCalls = 5;

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
                address(balancerV2BoostedPortal),
                0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            address(balancerV2BoostedPortal),
            abi.encodeWithSignature(
                "portal(address,uint256,address,address,bytes32,address)",
                intermediateToken,
                0,
                bb_a_dai,
                BalancerV2Vault,
                bb_a_daiPoolId,
                address(multicall)
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            bb_a_dai,
            bb_a_dai,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(balancerV2BoostedPortal),
                0
            ),
            1
        );
        calls[4] = IPortalsMulticall.Call(
            bb_a_dai,
            address(balancerV2BoostedPortal),
            abi.encodeWithSignature(
                "portal(address,uint256,address,address,bytes32,address)",
                bb_a_dai,
                0,
                outputToken,
                BalancerV2Vault,
                bb_a_usdPoolId,
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

    function test_PortalOut_BalancerV2Boosted_bb_a_USD_to_DAI()
        public
    {
        test_PortalIn_BalancerV2Boosted_bb_a_USD_with_ETH_with_DAI_Intermediate(
        );
        address inputToken = bb_a_usd;
        uint256 inputAmount = ERC20(inputToken).balanceOf(user);
        uint256 value = 0;
        address intermediateToken = bb_a_dai;

        address outputToken = DAI;

        uint256 numCalls = 4;

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
            inputToken,
            inputToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(balancerV2BoostedPortal),
                0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            inputToken,
            address(balancerV2BoostedPortal),
            abi.encodeWithSignature(
                "portal(address,uint256,address,address,bytes32,address)",
                inputToken,
                0,
                intermediateToken,
                BalancerV2Vault,
                bb_a_usdPoolId,
                address(multicall)
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(balancerV2BoostedPortal),
                0
            ),
            1
        );
        calls[3] = IPortalsMulticall.Call(
            intermediateToken,
            address(balancerV2BoostedPortal),
            abi.encodeWithSignature(
                "portal(address,uint256,address,address,bytes32,address)",
                intermediateToken,
                0,
                outputToken,
                BalancerV2Vault,
                bb_a_daiPoolId,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(inputToken).approve(address(router), type(uint256).max);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!router.paused());
        router.pause();
        assertTrue(router.paused());
        test_PortalIn_BalancerV2Boosted_bb_a_USD_with_ETH_with_DAI_Intermediate(
        );
    }

    function test_ERC20_recoverToken() public {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        ERC20(inputToken).transfer(
            address(balancerV2BoostedPortal), inputAmount
        );

        assertEq(
            ERC20(inputToken).balanceOf(
                address(balancerV2BoostedPortal)
            ),
            inputAmount
        );

        changePrank(owner);
        uint256 beforeRecovery = ERC20(inputToken).balanceOf(user);
        balancerV2BoostedPortal.recoverToken(
            inputToken, inputAmount, user
        );
        assertEq(
            ERC20(inputToken).balanceOf(user) - beforeRecovery,
            inputAmount
        );
    }
}

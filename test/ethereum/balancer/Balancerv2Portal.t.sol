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
import { BalancerV2Portal } from
    "../../../src/balancer/BalancerV2Portal.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract BalancerV2PortalTest is Test {
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
    address internal wstETH =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address internal wstETH_WETH =
        0x32296969Ef14EB0c6d29669C550D4a0449130230;
    address internal BalancerV2Vault =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router =
        new PortalsRouter(owner, collector, address(multicall));

    Addresses public addresses = new Addresses();

    BalancerV2Portal public balancerV2Portal =
        new BalancerV2Portal(addresses.get("Ethereum", "admin"));

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn_BalancerV2_wstETH_WETH_With_ETH_Using_WETH_Intermediate(
    ) public {
        address sellToken = address(0);
        uint256 sellAmount = 5 ether;
        uint256 value = sellAmount;

        address intermediateToken = WETH;

        address buyToken = wstETH_WETH;
        bytes32 poolId =
            0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080;

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

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);
        address[] memory assets = new address[](2);
        assets[0] = wstETH;
        assets[1] = WETH;

        calls[0] = IPortalsMulticall.Call(
            sellToken,
            intermediateToken,
            abi.encodeWithSignature("deposit()"),
            type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(balancerV2Portal),
                0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            address(balancerV2Portal),
            abi.encodeWithSignature(
                "portalIn(address,uint256,address,bytes32,address[],uint256,address)",
                intermediateToken,
                0,
                BalancerV2Vault,
                poolId,
                assets,
                1,
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

    function test_PortalOut_BalancerV2_wstETH_WETH_to_WETH() public {
        test_PortalIn_BalancerV2_wstETH_WETH_With_ETH_Using_WETH_Intermediate(
        );
        address sellToken = wstETH_WETH;
        uint256 sellAmount = ERC20(sellToken).balanceOf(user);
        uint256 value = 0;

        address buyToken = WETH;
        bytes32 poolId =
            0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080;

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

        address[] memory assets = new address[](2);
        assets[0] = wstETH;
        assets[1] = WETH;

        calls[0] = IPortalsMulticall.Call(
            sellToken,
            sellToken,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(balancerV2Portal),
                0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            sellToken,
            address(balancerV2Portal),
            abi.encodeWithSignature(
                "portalOut(address,uint256,address,bytes32,address[],uint256,address)",
                sellToken,
                0,
                BalancerV2Vault,
                poolId,
                assets,
                1,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        ERC20(sellToken).approve(address(router), type(uint256).max);

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
        test_PortalIn_BalancerV2_wstETH_WETH_With_ETH_Using_WETH_Intermediate(
        );
    }

    function testFail_Pausable_by_Admin_Only() public {
        assertTrue(!router.paused());
        router.pause();
    }
}

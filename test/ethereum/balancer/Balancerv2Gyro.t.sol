/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

import { PortalsRouter } from
    "../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../src/portals/multicall/PortalsMulticall.sol";
import { BalancerGyroscopePortal } from
    "../../../src/balancer/BalancerGyroscrope.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { Addresses } from "../../../script/constants/Addresses.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract BalancerGyroTest is Test {
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
    address internal GYD = 0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A; // Gyro Dollar
    address internal ETH = address(0);

    bytes32 internal poolId =
        0xc2aa60465bffa1a88f5ba471a59ca0435c3ec5c100020000000000000000062c;

    address internal gyroPool =
        0xC2AA60465BfFa1A88f5bA471a59cA0435c3ec5c1;
    address internal BalancerV2Vault =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Addresses public addresses = new Addresses();

    BalancerGyroscopePortal public gyroPortal =
        new BalancerGyroscopePortal(owner);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function test_PortalIn() public {
        address token0 = USDC;
        address token1 = GYD;
        address pool = gyroPool;
        address recipient = user;
        uint256 amount0 = 10 ** 6;
        uint256 amount1 = 1 ether;

        // Mimic sending Tokens to user for the purpose of this test
        deal(token0, recipient, amount0);
        deal(token1, recipient, amount1);

        // Check the initial WBNB balance of the user
        assertEq(ERC20(token0).balanceOf(recipient), amount0);
        assertEq(ERC20(token1).balanceOf(recipient), amount1);

        // Approve the amount to spend by the portal
        ERC20(token0).approve(address(gyroPortal), amount0);
        ERC20(token1).approve(address(gyroPortal), amount1);

        address[] memory tokens = new address[](2);

        tokens[0] = token0;
        tokens[1] = token1;

        // Perform the portalIn operation
        gyroPortal.portalIn(
            BalancerV2Vault, poolId, tokens, 1e18, recipient
        );

        uint256 finalBalance = ERC20(pool).balanceOf(recipient);

        uint256 finalBalanceToken0 =
            ERC20(token0).balanceOf(address(gyroPortal));
        uint256 finalBalanceToken1 =
            ERC20(token1).balanceOf(address(gyroPortal));

        assertTrue(
            finalBalanceToken0 == 0 || finalBalanceToken1 == 0,
            "One of the tokens should be 0 after portalIn"
        );

        uint256 inputBalance0 =
            ERC20(token0).balanceOf(address(recipient));
        uint256 inputBalance1 =
            ERC20(token1).balanceOf(address(recipient));

        console2.log("inputBalance0", inputBalance0);
        console2.log("inputBalance1", inputBalance1);

        assertTrue(
            finalBalance > 99_000,
            "Balance should be higher after portalIn"
        );
    }
}

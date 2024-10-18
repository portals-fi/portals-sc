// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { PortalsQuoter } from
    "../../../../src/portals/quoter/PortalsQuoter.sol";

import { IPortalsQuoter } from
    "../../../../src/portals/quoter/interface/IPortalsQuoter.sol";

contract PortalsQuoterEthereumTest is Test {
    PortalsQuoter public quoter;
    address constant CURVE_POOL =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // DAI/USDC/USDT pool
    address constant OLD_ASS_TRICRYPTO_POOL =
        0x5426178799ee0a0181A89b4f57eFddfAb49941Ec;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        uint256 mainnetFork =
            vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        quoter = new PortalsQuoter();
    }

    function testQuoteCurveDAIToUSDC() public {
        IPortalsQuoter.QuoteParams[] memory paramsArray =
            new IPortalsQuoter.QuoteParams[](1);
        paramsArray[0] = IPortalsQuoter.QuoteParams({
            protocol: 2, // Curve
            pool: CURVE_POOL,
            tokenIn: DAI,
            tokenOut: USDC,
            amount: 1000 * 1e18, // 1000 DAI
            fee: 0,
            quoteContract: address(0)
        });

        uint256 amountOut = quoter.quote(paramsArray);

        assertGt(
            amountOut, 0, "Quote should return a non-zero amount"
        );
        assertLt(
            amountOut,
            1000 * 1e6,
            "Quote should return less than 1000 USDC"
        );
    }

    function testQuoteCurveUSDCToDAI() public {
        IPortalsQuoter.QuoteParams[] memory paramsArray =
            new IPortalsQuoter.QuoteParams[](1);
        paramsArray[0] = IPortalsQuoter.QuoteParams({
            protocol: 2, // Curve
            pool: CURVE_POOL,
            tokenIn: USDC,
            tokenOut: DAI,
            amount: 1000 * 1e6, // 1000 USDC
            fee: 0,
            quoteContract: address(0)
        });

        uint256 amountOut = quoter.quote(paramsArray);

        assertGt(
            amountOut, 0, "Quote should return a non-zero amount"
        );
        assertLt(
            amountOut,
            1000 * 1e18,
            "Quote should return less than 1000 DAI"
        );
    }

    function testQuoteCurveWETHToUSDC() public {
        IPortalsQuoter.QuoteParams[] memory paramsArray =
            new IPortalsQuoter.QuoteParams[](1);
        paramsArray[0] = IPortalsQuoter.QuoteParams({
            protocol: 2, // Curve
            pool: OLD_ASS_TRICRYPTO_POOL,
            tokenIn: WETH,
            tokenOut: USDC,
            amount: 251_250_000_000_000_000, // 0.25125 WETH
            fee: 0,
            quoteContract: address(0)
        });

        uint256 amountOut = quoter.quote(paramsArray);

        assertGt(
            amountOut, 0, "Quote should return a non-zero amount"
        );
        // Assuming 1 WETH is roughly 2000 USDC, 0.25125 WETH should be around 500 USDC
        assertGt(
            amountOut,
            400 * 1e6,
            "Quote should return more than 400 USDC"
        );
    }
}

/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { PortalsQuoter } from
    "../../../src/portals/quoter/PortalsQuoter.sol";

import { IPortalsQuoter } from
    "../../../src/portals/quoter/interface/IPortalsQuoter.sol";

contract PortalsQuoterPolygonTest is Test {
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

    address internal USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address internal WMATIC =
        0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address internal IXT = 0xE06Bd4F5aAc8D0aA337D13eC88dB6defC6eAEefE;
    address internal SUSHI_WMATIC_IXT =
        0x014Ac2A53Aa6fBA4DcD93FdE6d3c787B79a1a6E6;
    address internal SUSHI_IXT_USDT =
        0xc879Bc72136cb6519b5e0e456bC9d727e106C582;
    address internal SUSHI_FACTORY =
        0xc35DADB65012eC5796536bD9864eD8773aBc74C4;

    PortalsQuoter public portalsQuoter = new PortalsQuoter();

    function test_Quote_UniswapV2() public {
        IPortalsQuoter.QuoteParams[] memory params =
            new IPortalsQuoter.QuoteParams[](2);

        params[0] = IPortalsQuoter.QuoteParams(
            0,
            30,
            0x014Ac2A53Aa6fBA4DcD93FdE6d3c787B79a1a6E6,
            0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            0xE06Bd4F5aAc8D0aA337D13eC88dB6defC6eAEefE,
            0x014Ac2A53Aa6fBA4DcD93FdE6d3c787B79a1a6E6,
            50_000_000_000_000_000
        );
        params[1] = IPortalsQuoter.QuoteParams(
            0,
            30,
            0xc879Bc72136cb6519b5e0e456bC9d727e106C582,
            0xE06Bd4F5aAc8D0aA337D13eC88dB6defC6eAEefE,
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            0xc879Bc72136cb6519b5e0e456bC9d727e106C582,
            0
        );

        uint256 outputAmount = portalsQuoter.quote(params);
        console.log("outputAmount: ", outputAmount);

        assertTrue(outputAmount > 0);
    }

    function test_Quote_Curve() public {
        IPortalsQuoter.QuoteParams[] memory params =
            new IPortalsQuoter.QuoteParams[](1);

        params[0] = IPortalsQuoter.QuoteParams(
            2,
            30,
            0x864490Cf55dc2Dee3f0ca4D06F5f80b2BB154a03,
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            0xc4Ce1D6F5D98D65eE25Cf85e9F2E9DcFEe6Cb5d6,
            0x864490Cf55dc2Dee3f0ca4D06F5f80b2BB154a03,
            25_000_000_000
        );

        uint256 outputAmount = portalsQuoter.quote(params);
        console.log("outputAmount: ", outputAmount);

        assertTrue(outputAmount > 0);
    }

    function test_Quote_BalancerV2() public {
        IPortalsQuoter.QuoteParams[] memory params =
            new IPortalsQuoter.QuoteParams[](1);

        params[0] = IPortalsQuoter.QuoteParams(
            4,
            0,
            0x0297e37f1873D2DAb4487Aa67cD56B58E2F27875,
            0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            0xE39B5e3B6D74016b2F6A9673D7d7493B6DF549d5,
            25_000_000_000_000_000_000
        );

        uint256 outputAmount = portalsQuoter.quote(params);
        console.log("outputAmount: ", outputAmount);

        assertTrue(outputAmount > 0);
    }

    function test_Quote_UniswapV3() public {
        IPortalsQuoter.QuoteParams[] memory params =
            new IPortalsQuoter.QuoteParams[](1);

        params[0] = IPortalsQuoter.QuoteParams(
            1,
            3000,
            0x07A0e5CC33F3f28Cf655D7a76334D0b1BAB5b704,
            0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a,
            0x61fFE014bA17989E743c5F6cB21bF9697530B21e,
            25_000_000_000_000_000
        );

        uint256 outputAmount = portalsQuoter.quote(params);
        console.log("outputAmount: ", outputAmount);

        assertTrue(outputAmount > 0);
    }

    // function test_Quote_Solidly() public {
    //     IPortalsQuoter.QuoteParams[] memory params =
    //         new IPortalsQuoter.QuoteParams[](1);

    //     params[0] = IPortalsQuoter.QuoteParams(
    //         3,
    //         0,
    //         0xd25711EdfBf747efCE181442Cc1D8F5F8fc8a0D3,
    //         0x4200000000000000000000000000000000000006,
    //         0x4200000000000000000000000000000000000042,
    //         0xd25711EdfBf747efCE181442Cc1D8F5F8fc8a0D3,
    //         2_500_000_000_000_000_000
    //     );

    //     uint256 outputAmount = portalsQuoter.quote(params);
    //     console.log("outputAmount: ", outputAmount);

    //     assertTrue(outputAmount > 0);
    // }
}

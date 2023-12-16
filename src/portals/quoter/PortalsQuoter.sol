/// SPDX-License-Identifier: MIT

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract gets quotes for swap routes
/// @notice Adapted from https://github.com/solidquant/swap-simulator-v1/blob/main/src/SimulatorV1.sol by vorg-san

pragma solidity 0.8.19;

import { UniswapV2Library } from "./lib/UniswapV2Library.sol";
import { IQuoterV2 } from "./interface/IQuoterV2.sol";
import { ICurvePool } from "./interface/ICurvePool.sol";
import { ISolidlyPool } from "./interface/ISolidlyPool.sol";
import { IBalancerQueries } from "./interface/IBalancerQueries.sol";

contract PortalsQuoter {
    struct QuoteParams {
        uint8 protocol;
        uint24 fee;
        address pool;
        address tokenIn;
        address tokenOut;
        address quoteContract;
        uint256 amount;
    }

    constructor() { }

    function quote(QuoteParams[] calldata paramsArray)
        external
        view
        returns (uint256)
    {
        uint256 amountOut = 0;
        uint256 paramsArrayLength = paramsArray.length;

        for (uint256 i; i < paramsArrayLength;) {
            QuoteParams memory params = paramsArray[i];

            if (amountOut == 0) {
                amountOut = params.amount;
            } else {
                params.amount = amountOut;
            }

            if (params.protocol == 0) {
                amountOut = _quoteUniswapV2(params);
            } else if (params.protocol == 1) {
                amountOut = _quoteUniswapV3(params);
            } else if (params.protocol == 2) {
                amountOut = _quoteCurve(params);
            } else if (params.protocol == 3) {
                amountOut = _quoteSolidly(params);
            } else if (params.protocol == 4) {
                amountOut = _quoteBalancerV2(params);
            }

            unchecked {
                i++;
            }
        }

        return amountOut;
    }

    function _quoteUniswapV2(QuoteParams memory params)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 reserveIn, uint256 reserveOut) = UniswapV2Library
            .getReserves(
            params.quoteContract, params.tokenIn, params.tokenOut
        );

        uint256 amountInWithFee =
            params.amount * (10_000 - params.fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10_000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _quoteUniswapV3(QuoteParams memory params)
        internal
        view
        returns (uint256 amountOut)
    {
        IQuoterV2 quoter = IQuoterV2(params.quoteContract);
        IQuoterV2.QuoteExactInputSingleParams memory quoterParams;
        quoterParams.tokenIn = params.tokenIn;
        quoterParams.tokenOut = params.tokenOut;
        quoterParams.amountIn = params.amount;
        quoterParams.fee = params.fee;
        quoterParams.sqrtPriceLimitX96 = 0;
        (amountOut,,,) = quoter.quoteExactInputSingle(quoterParams);
    }

    function _quoteCurve(QuoteParams memory params)
        internal
        view
        returns (uint256 amountOut)
    {
        ICurvePool pool = ICurvePool(params.pool);

        int128 i = 0;
        int128 j = 0;

        int128 coinIdx = 0;

        while (i == j) {
            address coin = pool.coins(coinIdx);

            if (coin == params.tokenIn) {
                i = coinIdx;
            } else if (coin == params.tokenOut) {
                j = coinIdx;
            }

            if (i != j) {
                break;
            }

            unchecked {
                coinIdx++;
            }
        }

        amountOut =
            ICurvePool(params.pool).get_dy(i, j, params.amount);
    }

    function _quoteSolidly(QuoteParams memory params)
        public
        view
        returns (uint256 amountOut)
    {
        ISolidlyPool quoter = ISolidlyPool(params.quoteContract);
        amountOut = quoter.getAmountOut(params.amount, params.tokenIn);
    }

    function _quoteBalancerV2(QuoteParams memory params)
        internal
        view
        returns (uint256 amountOut)
    {
        amountOut = IBalancerQueries(params.quoteContract).querySwap(
            IBalancerQueries.SingleSwap({
                poolId: IBalancerQueries(params.pool).getPoolId(),
                kind: IBalancerQueries.SwapKind.GIVEN_IN,
                assetIn: params.tokenIn,
                assetOut: params.tokenOut,
                amount: params.amount,
                userData: bytes("")
            }),
            IBalancerQueries.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            })
        );
    }
}

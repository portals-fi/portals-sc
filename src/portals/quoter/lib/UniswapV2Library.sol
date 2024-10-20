// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IUniswapV2Pair } from
    "../../../uniswap/interface/IUniswapV2Pair.sol";
import { SafeMath } from
    "openzeppelin-contracts/utils/math/SafeMath.sol";

library UniswapV2Library {
    using SafeMath for uint256;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(
            tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES"
        );
        (token0, token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(
            token0 != address(0), "UniswapV2Library: ZERO_ADDRESS"
        );
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB)
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        bytes32 initCodeHash =
            0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), factory, salt, initCodeHash
                        )
                    )
                )
            )
        );

        return pair;
    }

    // fetches and sorts the reserves for a pair
    // Pass in pair instead of calculating it as initCodeHash is different for forks
    function getReserves(address pair, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) =
            IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }
}

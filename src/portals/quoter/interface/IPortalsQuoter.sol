// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPortalsQuoter {
    struct QuoteParams {
        uint8 protocol;
        uint24 fee;
        address pool;
        address tokenIn;
        address tokenOut;
        address quoteContract;
        uint256 amount;
    }
}

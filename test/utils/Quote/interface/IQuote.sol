/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IQuote {
    struct QuoteParams {
        address sellToken;
        address buyToken;
        uint256 sellAmount;
    }
}

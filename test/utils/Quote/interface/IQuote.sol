/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IQuote {
    struct QuoteParams {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        string slippagePercentage; // between 0 and 1 (e.g. 0.005 for 0.5%)
    }
}

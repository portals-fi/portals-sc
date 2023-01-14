/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice A utility contract for getting quotes from portals or dex
/// aggregators

/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IQuote } from "./interface/IQuote.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Surl } from "surl/Surl.sol";

contract Quote is IQuote, Script {
    using Surl for *;

    address constant ETH_ALT =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function swap(QuoteParams memory quoteParams)
        public
        returns (bytes memory)
    {
        if (quoteParams.sellToken == address(0)) {
            quoteParams.sellToken = ETH_ALT;
        }
        if (quoteParams.buyToken == address(0)) {
            quoteParams.sellToken = ETH_ALT;
        }
        string memory url = "https://api.1inch.io/v5.0/1/swap";
        string memory params = string.concat(
            "?fromAddress=",
            vm.toString(address(0)),
            "&fromTokenAddress=",
            vm.toString(quoteParams.sellToken),
            "&toTokenAddress=",
            vm.toString(quoteParams.buyToken),
            "&amount=",
            vm.toString(quoteParams.sellAmount),
            "&slippage=",
            vm.toString(uint256(3)),
            "&allowPartialFill=false",
            "&disableEstimate=true"
        );

        string[] memory headers = new string[](2);
        headers[0] = "accept: application/json";
        headers[1] =
            "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15";

        string memory request = string.concat(url, params);
        (uint256 status, bytes memory data) = request.get(headers);
        if (status != 200) {
            console2.log(string(data));
            revert("API ERROR");
        }

        return data;
    }
}

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice A utility contract for getting quotes from portals or dex
/// aggregators

/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { IQuote } from "./interface/IQuote.sol";
import { console2 } from "forge-std/console2.sol";
import { Surl } from "surl/Surl.sol";

contract Quote is IQuote, Script {
    using Surl for *;

    address constant ETH_ALT =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function portal(QuoteParams memory quoteParams)
        public
        returns (bytes memory)
    {
        string memory url =
            "https://api.portals.fi/v1/portal/ethereum";
        string memory params = string.concat(
            "?takerAddress=",
            vm.toString(address(0)),
            "&sellToken=",
            vm.toString(quoteParams.sellToken),
            "&buyToken=",
            vm.toString(quoteParams.buyToken),
            "&sellAmount=",
            vm.toString(quoteParams.sellAmount),
            "&slippagePercentage=0.03",
            "&validate=false"
        );

        string[] memory headers = new string[](2);
        headers[0] = "accept: application/json";
        headers[1] = "User-Agent: portals-sc";

        string memory request = string.concat(url, params);

        (uint256 status, bytes memory data) = request.get(headers);
        if (status != 200) {
            console2.log(string(data));
            revert("API ERROR");
        }
        return data;
    }
}

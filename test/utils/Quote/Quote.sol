/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice A utility contract for getting quotes from portals or dex
/// aggregators

pragma solidity ^0.8.0;

import { IQuote } from "./interface/IQuote.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Surl } from "surl/Surl.sol";

contract Quote is IQuote, Script {
    using Surl for *;
    using stdJson for string;

    function quote(QuoteParams memory quoteParams)
        public
        returns (address, bytes memory)
    {
        string memory url = "https://api.portals.fi/v2/portal";
        string memory params = string.concat(
            "?sender=",
            vm.toString(address(0)),
            "&inputToken=",
            "arbitrum:",
            vm.toString(quoteParams.sellToken),
            "&outputToken=",
            "arbitrum:",
            vm.toString(quoteParams.buyToken),
            "&inputAmount=",
            vm.toString(quoteParams.sellAmount),
            "&slippageTolerancePercentage=",
            quoteParams.slippagePercentage,
            "&validate=false"
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
        string memory json = string(data);

        return
            (json.readAddress(".tx.to"), json.readBytes(".tx.data"));
    }

    // add this to be excluded from coverage report
    function test() public { }
}

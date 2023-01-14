/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests PortalsRouter.sol

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { PortalsRouter } from
    "../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../src/portals/router/PortalsMulticall.sol";
import { IPortalsRouter } from
    "../../../src/portals/router/interface/IPortalsRouter.sol";

import { Quote } from "../../utils/Quote/Quote.sol";
import { IQuote } from "../../utils/Quote/interface/IQuote.sol";

contract PortalsRouterTest is Test {
    PortalsRouter public router;
    PortalsMulticall public multicall;
    Quote public quote;

    uint256 internal ownerPrivateKey;
    uint256 internal userPrivateKey;
    uint256 internal collectorPivateKey;
    uint256 internal adversaryPivateKey;
    uint256 internal partnerPivateKey;

    address internal owner;
    address internal user;
    address internal collector;
    address internal adversary;
    address internal partner;

    function setUp() public {
        ownerPrivateKey = 0xDAD;
        userPrivateKey = 0xB0B;
        collectorPivateKey = 0xA11CE;
        adversaryPivateKey = 0xC0C;
        partnerPivateKey = 0xABE;

        owner = vm.addr(ownerPrivateKey);
        user = vm.addr(userPrivateKey);
        collector = vm.addr(collectorPivateKey);
        adversary = vm.addr(adversaryPivateKey);
        partner = vm.addr(partnerPivateKey);

        multicall = new PortalsMulticall();

        router =
            new PortalsRouter(owner, 0, collector, address(multicall));

        quote = new Quote();
    }

    function testStargatePortalToSUSDCFromETH() public {
        address sellToken = address(0);
        address intermediateToken =
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        address buyToken = 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56;
        uint256 poolId = 1;

        uint256 sellAmount = 5 ether;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: buyToken,
            minBuyAmount: 0,
            fee: 0,
            recipient: user,
            partner: partner
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams({
            sellToken: sellToken,
            sellAmount: sellAmount,
            buyToken: intermediateToken
        });

        bytes memory data = quote.swap(quoteParams);
        assertGt(data.length, 0);
    }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}

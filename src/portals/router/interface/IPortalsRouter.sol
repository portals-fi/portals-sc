/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IPortalsRouter {
    struct Order {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        uint256 minBuyAmount;
        uint256 fee;
        address recipient;
        address partner;
    }

    struct SignedOrder {
        Order order;
        address sender;
        uint32 deadline;
        uint32 nonce;
        address broadcaster;
        uint256 gasFee;
    }

    struct SignedOrderPayload {
        SignedOrder signedOrder;
        bytes signature;
    }

    struct PermitPayload {
        address owner;
        uint256 amount;
        uint256 deadline;
        bytes signature;
        bool splitSignature;
    }
}

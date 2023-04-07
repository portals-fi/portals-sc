/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice Interface for the Portals Router contract

/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { IPortalsMulticall } from
    "../..//multicall/interface/IPortalsMulticall.sol";

interface IPortalsRouter {
    /// @param sellToken The ERC20 token address to spend (address(0) if network token)
    /// @param sellAmount The quantity of sellToken to Portal
    /// @param buyToken The ERC20 token address to buy (address(0) if network token)
    /// @param minBuyAmount The minimum acceptable quantity of buyToken to receive. Reverts otherwise.
    /// @param feeToken The ERC20 token address to pay fees in (address(0) if network token)
    /// @param fee The total fee in base units of feeToken (including gas fee if applicable)
    /// @param recipient The recipient of the buyToken
    /// @param partner The front end operator address
    struct Order {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        uint256 minBuyAmount;
        address feeToken;
        uint256 fee;
        address recipient;
        address partner;
    }

    /// @param order The order containing the details of the trade
    /// @param calls The calls to be executed in the aggregate function of PortalsMulticall.sol to transform
    /// sellToken to buyToken
    struct OrderPayload {
        Order order;
        IPortalsMulticall.Call[] calls;
    }

    /// @param order The order containing the details of the trade
    /// @param sender The signer of the order and the sender of the sellToken
    /// @param deadline The deadline after which the order is no longer valid
    /// @param nonce The nonce of the sender(signer)
    struct SignedOrder {
        Order order;
        address sender;
        uint64 deadline;
        uint64 nonce;
    }

    /// @param signedOrder The signed order containing the details of the trade
    /// @param signature The signature of the signed order
    /// @param calls The calls to be executed in the aggregate function of PortalsMulticall.sol to transform
    /// sellToken to buyToken
    struct SignedOrderPayload {
        SignedOrder signedOrder;
        bytes signature;
        IPortalsMulticall.Call[] calls;
    }

    /// @param owner The address which is a source of funds and has signed the Permit
    /// @param amount The quantity of tokens to be spent
    /// @param deadline The timestamp after which the Permit is no longer valid
    /// @param signature The signature of the Permit
    /// @param splitSignature Whether the signature is split into r, s, and v
    /// @param daiPermit Whether the Permit is a DAI Permit (i.e not  EIP-2612)
    struct PermitPayload {
        address owner;
        uint256 amount;
        uint256 deadline;
        bytes signature;
        bool splitSignature;
        bool daiPermit;
    }
}

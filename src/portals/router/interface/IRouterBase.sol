/// Copyright (C) 2022 Portals.fi

/// @author Portals.fi
/// @notice Interface for the Base contract inherited by Portals

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IRouterBase {
    /// @notice Emitted when portalling
    /// @param sellToken The ERC20 token address to spend (address(0) if network
    /// token)
    /// @param sellAmount The quantity of sellToken to Portal out
    /// @param buyToken The ERC20 token address to buy (address(0) if network
    /// token)
    /// @param buyAmount The quantity of buyToken received
    /// @param fee The fee in BPS
    /// @param sender The  msg.sender
    /// @param partner The front end operator address
    event Portal(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        uint256 buyAmount,
        uint256 baseFee,
        uint256 fee,
        address indexed sender,
        address indexed recipient,
        address indexed partner
    );

    /// @notice Emitted when the fee is changed
    /// @param fee The new fee in BPS
    event Fee(uint256 fee);

    /// @notice Emitted when the collector is changed
    /// @param collector The new collector
    event Collector(address collector);

    /// @notice Emitted when/if the router is paused
    /// @param paused The active status of this contract. If false, contract is
    /// active (i.e un-paused)
    event Pause(bool paused);

    /// Thrown when insufficient liquidity is received after deposit or
    /// withdrawal
    /// @param buyAmount The amount of liquidity received
    /// @param minBuyAmount The minimum acceptable quantity of liquidity
    /// received
    error InsufficientBuy(uint256 buyAmount, uint256 minBuyAmount);
}

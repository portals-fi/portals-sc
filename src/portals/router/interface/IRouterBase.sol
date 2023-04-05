/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice Interface for the Base contract inherited by the Portals Router

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IRouterBase {
    /// @notice Emitted when Portalling
    /// @param sellToken The ERC20 token address to spend (address(0) if network token)
    /// @param sellAmount The quantity of sellToken to send
    /// @param buyToken The ERC20 token address to buy (address(0) if network token)
    /// @param buyAmount The quantity of buyToken received
    /// @param feeToken The ERC20 token address to pay fees in (address(0) if network token)
    /// @param fee The total fee in base units of feeToken (including gas fee if applicable)
    /// @param sender The msg.sender
    /// @param recipient The recipient of the buyToken
    /// @param partner The front end operator address
    event Portal(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        uint256 buyAmount,
        address feeToken,
        uint256 fee,
        address indexed sender,
        address indexed broadcaster,
        address recipient,
        address indexed partner
    );

    /// @notice Emitted when the collector is changed
    /// @param collector The new collector
    event Collector(address collector);

    /// @notice Emitted when the Portals multicall is changed
    /// @param multicall The new multicall contract
    event Multicall(address multicall);

    /// @notice Emitted when this contract is paused
    /// @param paused The active status of this contract. If false, contract is active (i.e un-paused)
    event Pause(bool paused);

    /// Thrown when insufficient liquidity is received after deposit or withdrawal
    /// @param buyAmount The amount of liquidity received
    /// @param minBuyAmount The minimum acceptable quantity of liquidity received
    error InsufficientBuy(uint256 buyAmount, uint256 minBuyAmount);
}

/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract collects tokens from the Portals ecosystem on behalf of partners.
/// @dev ERC20 tokens should be sent directly to the contract while native tokens should be sent via
/// the receive() function.

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";

contract PortalsCollector is Owned {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// @notice Emitted when collecting the native token
    /// @param amount The quantity of native token collected
    event Collect(uint256 amount);

    /// @notice Emitted when dolling tokens to partners
    /// @param token The ERC20 token being to sent (address(0) if network token)
    /// @param amount The quantity of tokens sent
    /// @param partner The address of the partner receiving the tokens
    event Dole(address token, uint256 amount, address partner);

    constructor(address _admin) Owned(_admin) { }

    /// @notice Sends collected tokens to partners
    /// @param tokenAddresses An array of the address of the tokens to send (address(0) if ETH)
    /// @param tokenAmounts An array of the quantity of tokens to send
    /// @param partner The address to send the tokens to
    function dole(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenAmounts,
        address partner
    ) external onlyOwner {
        address tokenAddress;
        uint256 tokenAmount;
        require(
            tokenAddresses.length == tokenAmounts.length,
            "PortalsCollector: length mismatch"
        );
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokenAddress = tokenAddresses[i];
            tokenAmount = tokenAmounts[i];
            if (tokenAddress == address(0)) {
                partner.safeTransferETH(tokenAmount);
            } else {
                ERC20(tokenAddress).safeTransfer(partner, tokenAmount);
            }
            emit Dole(tokenAddress, tokenAddress, partner);
        }
    }

    receive() external payable {
        emit Collect(msg.value);
    }
}

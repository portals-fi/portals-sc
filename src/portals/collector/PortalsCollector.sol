/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract collects tokens from the Portals ecosystem on behalf of partners

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Pausable } from
    "openzeppelin-contracts/security/Pausable.sol";

contract PortalsCollector is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// @notice Emitted when collecting tokens
    /// @param token The ERC20 token address collected (address(0) if network token)
    /// @param partnerAmount The quantity of tokens collected for the partner
    /// @param partner The address of the partner receiving the tokens
    /// @param cacheAmount The quantity of tokens sent to the cache
    /// @param cache The address of the cache
    event Collect(
        address token,
        uint256 partnerAmount,
        address partner,
        uint256 cacheAmount,
        address cache
    );

    /// @notice Emitted when distributing tokens to partners
    /// @param token The ERC20 token being to sent (address(0) if network token)
    /// @param amount The quantity of tokens sent
    /// @param partner The address of the partner receiving the tokens
    /// @param partner The address of the distributor who pays gas to send the tokens
    event Distribute(
        address token,
        uint256 amount,
        address partner,
        address distributor
    );

    mapping(address partner => mapping(address token => uint256 owed))
        public partners;

    mapping(address partner => uint256 amount) public rake;

    address public cache;

    constructor(address _admin, address _cache) Owned(_admin) {
        cache = _cache;
    }

    /// @notice Sends collected tokens to partners
    /// @param tokenAddresses An array of the address of the tokens to send (address(0) if ETH)
    /// @param partner The address to send the tokens to
    function distribute(
        address partner,
        address[] calldata tokenAddresses
    ) external whenNotPaused {
        address tokenAddress;
        uint256 tokenAmount;
        for (uint256 i = 0; i < tokenAddresses.length;) {
            tokenAddress = tokenAddresses[i];
            tokenAmount = partners[partner][tokenAddress];
            partners[partner][tokenAddress] = 0;
            if (tokenAddress == address(0)) {
                partner.safeTransferETH(tokenAmount);
            } else {
                ERC20(tokenAddress).safeTransfer(partner, tokenAmount);
            }
            emit Distribute(
                tokenAddress, tokenAmount, partner, msg.sender
            );
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Collects fee tokens
    /// @param token The ERC20 token address to collect (address(0) if network token)
    /// @param amount The total quantity of tokens to collect
    /// @param portalsFee The quantity of tokens to be sent to the cache
    /// @param partner The address of the partner
    function collect(
        address token,
        uint256 amount,
        uint256 portalsFee,
        address partner
    ) external payable {
        uint256 partnerAmount;
        uint256 cacheAmount;
        if (token == address(0)) {
            partnerAmount = msg.value - portalsFee;
            cacheAmount = msg.value - partnerAmount;
            partners[partner][token] += partnerAmount;
            partners[cache][token] += cacheAmount;
        } else {
            require(
                msg.value == 0,
                "PortalsCollector: Native token sent with ERC20 token"
            );
            ERC20(token).safeTransferFrom(
                msg.sender, address(this), amount
            );
            partnerAmount = amount - portalsFee;
            if (portalsFee > 0) cacheAmount = amount - partnerAmount;
            partners[partner][token] += partnerAmount;
            partners[cache][token] += cacheAmount;
        }
        emit Collect(
            token, partnerAmount, partner, cacheAmount, cache
        );
    }

    function updateCache(address _cache) external onlyOwner {
        cache = _cache;
    }

    /// @dev Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Recovers tokens if needed
    /// @param tokenAddress The address of the token to recover (address(0) if ETH)
    /// @param tokenAmount The quantity of tokens to recover
    /// @param to The address to send the recovered tokens to
    function recoverToken(
        address tokenAddress,
        uint256 tokenAmount,
        address to
    ) external onlyOwner {
        if (tokenAddress == address(0)) {
            to.safeTransferETH(tokenAmount);
        } else {
            ERC20(tokenAddress).safeTransfer(to, tokenAmount);
        }
    }
}

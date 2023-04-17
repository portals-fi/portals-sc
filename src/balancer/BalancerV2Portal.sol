/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract adds liquidity to Balancer V2 like pools using any ERC20 token or the network token.
/// @note This contract is intended to be consumed via a multicall contract and as such omits various checks
/// including slippage and does not return the quantity of tokens acquired. These checks should be handled
/// by the caller

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { IBalancerVault } from "./interface/IBalancerVault.sol";

contract BalancerV2Portal is Owned {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    // Active status of this contract. If false, contract is active (i.e un-paused)
    bool public paused;

    // Circuit breaker
    modifier pausable() {
        require(!paused, "Paused");
        _;
    }

    /// @notice Emitted when a portal is paused
    /// @param paused The active status of this contract. If false, contract is active (i.e un-paused)
    event Pause(bool paused);

    constructor(address admin) Owned(admin) { }

    /// @notice Add liquidity to Balancer V2 like pools with network tokens/ERC20 tokens
    /// @param sellToken The ERC20 token address to spend (address(0) if network token)
    /// @param sellAmount The quantity of sellToken to Portal in
    /// @param vault The Balancer V2 like vault to be used for adding liquidity
    /// @param poolId The ID of the pool to add liquidity to
    /// @param assets The assets in the pool
    /// @param index The index of the asset to add
    /// @param recipient The recipient of the liquidity tokens
    function portalIn(
        address sellToken,
        uint256 sellAmount,
        address vault,
        bytes32 poolId,
        address[] memory assets,
        uint256 index,
        address recipient
    ) external payable pausable {
        uint256 amount = _transferFromCaller(sellToken, sellAmount);

        uint256[] memory maxAmountsIn = new uint256[](assets.length);
        maxAmountsIn[index] = amount;

        bytes memory userData = abi.encode(1, maxAmountsIn, 0);

        uint256 valueToSend;
        if (sellToken == address(0)) {
            valueToSend = sellAmount;
        } else {
            _approve(sellToken, vault);
        }

        IBalancerVault(vault).joinPool{ value: valueToSend }(
            poolId,
            address(this),
            recipient,
            IBalancerVault.JoinPoolRequest({
                assets: assets,
                maxAmountsIn: maxAmountsIn,
                userData: userData,
                fromInternalBalance: false
            })
        );
    }

    /// @notice Transfers tokens or the network token from the caller to this contract
    /// @param token The address of the token to transfer (address(0) if network token)
    /// @param quantity The quantity of tokens to transfer from the caller
    /// @return The quantity of tokens or network tokens transferred from the caller to this contract
    function _transferFromCaller(address token, uint256 quantity)
        internal
        virtual
        returns (uint256)
    {
        if (token == address(0)) {
            require(msg.value > 0, "Invalid msg.value");
            return msg.value;
        }

        require(
            quantity > 0 && msg.value == 0,
            "Invalid quantity or msg.value"
        );
        ERC20(token).safeTransferFrom(
            msg.sender, address(this), quantity
        );

        return quantity;
    }

    /// @notice Approve a token for spending with infinite allowance
    /// @param token The ERC20 token to approve
    /// @param spender The spender of the token
    function _approve(address token, address spender) internal {
        ERC20 _token = ERC20(token);
        if (_token.allowance(address(this), spender) == 0) {
            _token.safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev Pause or unpause the contract
    function pause() external onlyOwner {
        paused = !paused;
        emit Pause(paused);
    }

    /// @notice Recovers stuck tokens
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

    /// @notice Reverts if networks tokens are sent directly to this contract
    receive() external payable {
        require(msg.sender != tx.origin);
    }
}

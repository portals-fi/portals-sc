/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract adds liquidity to Gamma-like pools using any ERC20 token,
/// or the network token.
/// @note This contract is intended to be consumed via a multicall contract and as such omits various checks
/// including slippage and does not return the quantity of tokens acquired. These checks should be handled
/// by the caller

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Pausable } from
    "openzeppelin-contracts/security/Pausable.sol";

import { IUniProxy } from "./interface/IUniProxy.sol";

contract GammaThenaPortal is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    constructor(address admin) Owned(admin) { }

    /// @notice Add liquidity to Hop-like pools with network tokens/ERC20 tokens
    /// @param router The address of the Gamma-like router
    /// @param token0 The address of the first token
    /// @param token1 The address of the second token
    /// @param poolAddress The Gamma-like pool address
    /// @param recipient The recipient of the liquidity tokens
    function portalIn(
        address router,
        address token0,
        address token1,
        address poolAddress,
        address recipient
    ) external payable whenNotPaused {
        // Get available balance of token0 and token1
        uint256 balance0 = ERC20(token0).balanceOf(msg.sender);
        uint256 balance1 = ERC20(token1).balanceOf(msg.sender);

        // Get Depopsit Amount Options
        IUniProxy uniProxy = IUniProxy(router);

        (uint256 amount1Start, uint256 amount1End) =
            uniProxy.getDepositAmount(poolAddress, token0, balance0);
        (uint256 amount0Start, uint256 amount0End) =
            uniProxy.getDepositAmount(poolAddress, token1, balance1);

        uint256 zero = 0;

        if (
            balance1 >= amount1Start && balance1 <= amount1End
                && balance0 >= amount0Start && balance0 <= amount0End
        ) {
            // Perfect case
            ERC20(token0).safeTransferFrom(
                msg.sender, address(this), balance0
            );
            ERC20(token1).safeTransferFrom(
                msg.sender, address(this), balance1
            );
            ERC20(token0).safeApprove(poolAddress, balance0);
            ERC20(token1).safeApprove(poolAddress, balance1);
            uniProxy.deposit(
                balance0,
                balance1,
                recipient,
                poolAddress,
                [zero, zero, zero, zero]
            );
            return;
        }

        if (balance1 <= amount1End && balance0 >= amount0End) {
            ERC20(token0).safeTransferFrom(
                msg.sender, address(this), amount0End
            );
            ERC20(token1).safeTransferFrom(
                msg.sender, address(this), balance1
            );
            ERC20(token0).safeApprove(poolAddress, amount0End);
            ERC20(token1).safeApprove(poolAddress, balance1);
            uniProxy.deposit(
                amount0End,
                balance1,
                recipient,
                poolAddress,
                [zero, zero, zero, zero]
            );
            return;
        }

        if (balance1 >= amount1Start && balance1 >= amount1End) {
            ERC20(token0).safeTransferFrom(
                msg.sender, address(this), balance0
            );
            ERC20(token1).safeTransferFrom(
                msg.sender, address(this), amount1End
            );
            ERC20(token0).safeApprove(poolAddress, balance0);
            ERC20(token1).safeApprove(poolAddress, amount1End);
            uniProxy.deposit(
                balance0,
                amount1End,
                recipient,
                poolAddress,
                [zero, zero, zero, zero]
            );
            return;
        }

        revert("GammaThenaPortal: Insufficient balance");
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
            require(msg.value != 0, "Invalid msg.value");
            return msg.value;
        }

        require(
            quantity != 0 && msg.value == 0,
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

    /// @dev Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
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

    receive() external payable { }
}

/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract adds liquidity to Velodrome V2-like pools using any ERC20 token.
/// @dev This contract is intended to be consumed via a multicall contract and as such omits various checks
/// including slippage and does not return the quantity of tokens acquired. These checks should be handled
/// by the caller

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Pausable } from
    "openzeppelin-contracts/security/Pausable.sol";
import { IVelodromeV2Router02 } from
    "./interface/IVelodromeV2Router02.sol";

contract VelodromeV2Portal is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    constructor(address admin) Owned(admin) { }

    /// @notice Add liquidity to Velodrome V2-like pools
    /// @param tokenA The pool's first underlying token
    /// @param tokenB The pool's second underlying token
    /// @param router The Velodrome V2-like router to be used for adding liquidity
    /// @param stable True if pool is stable, false if volatile
    /// @param recipient The recipient of the liquidity tokens
    function portalIn(
        address tokenA,
        address tokenB,
        IVelodromeV2Router02 router,
        bool stable,
        address recipient
    ) external payable whenNotPaused {
        uint256 amountA = _getBalance(address(this), tokenA);
        uint256 amountB = _getBalance(address(this), tokenB);

        _approve(tokenA, address(router));
        _approve(tokenB, address(router));

        (uint256 amountASent, uint256 amountBsent,) = router
            .addLiquidity(
            tokenA,
            tokenB,
            stable,
            amountA,
            amountB,
            0,
            0,
            recipient,
            block.timestamp
        );

        if (amountA > amountASent) {
            ERC20(tokenA).safeTransfer(
                recipient, amountA - amountASent
            );
        }
        if (amountB > amountBsent) {
            ERC20(tokenB).safeTransfer(
                recipient, amountB - amountBsent
            );
        }
    }

    /// @notice Get the ERC20 or network token balance of an account
    /// @param account The owner of the tokens or network tokens whose balance is being queried
    /// @param token The address of the token (address(0) if network token)
    /// @return The accounts's token or network token balance
    function _getBalance(address account, address token)
        internal
        view
        returns (uint256)
    {
        if (token == address(0)) {
            return account.balance;
        } else {
            return ERC20(token).balanceOf(account);
        }
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

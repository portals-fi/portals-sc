/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Pausable } from
    "openzeppelin-contracts/security/Pausable.sol";
import { IBalancerVault } from "./interface/IBalancerVault.sol";

contract BalancerGyroscopePortal is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    constructor(address admin) Owned(admin) { }

    /// @notice Add liquidity to Balancer V2 like pools using network tokens/ERC20 tokens
    /// @param vault The Balancer V2 like vault to be used for adding liquidity
    /// @param poolId The ID of the pool to add liquidity to
    /// @param assets The assets to be deposited into the pool
    /// @param bltOutAmount The quantity of Balancer Pool Tokens (BPT) to be minted
    /// @param recipient The recipient of the minted BPT
    function portalIn(
        address vault,
        bytes32 poolId,
        address[] calldata assets,
        uint256 bltOutAmount,
        address recipient
    ) external payable whenNotPaused {
        uint256[] memory maxAmountsIn = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            maxAmountsIn[i] = ERC20(assets[i]).balanceOf(msg.sender);

            _transferFromCaller(assets[i], maxAmountsIn[i]);
            _approve(assets[i], vault);
        }

        // ALL_TOKENS_IN_FOR_EXACT_BPT_OUT = 3
        bytes memory userData = abi.encode(3, bltOutAmount);

        IBalancerVault(vault).joinPool(
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

        // Return dust
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 dustBalance =
                ERC20(assets[i]).balanceOf(address(this));

            ERC20(assets[i]).transfer(recipient, dustBalance);
        }
    }

    /// @notice Remove liquidity from Balancer V2 like pools into network tokens/ERC20 tokens
    /// @param vault The Balancer V2 like vault to be used for removing liquidity
    /// @param poolId The ID of the pool to add liquidity to
    /// @param inputToken The Balancer V2 like pool address (i.e. the LP token address)
    /// @param inputAmount The quantity of inputToken to Portal out
    /// @param assets The assets underlying the pool
    /// @param minAmountsOut The minimum amounts of each token to be received
    /// @param recipient The recipient of the output tokens
    function portalOut(
        address vault,
        bytes32 poolId,
        address inputToken,
        uint256 inputAmount,
        address[] calldata assets,
        uint256[] calldata minAmountsOut,
        address payable recipient
    ) external payable whenNotPaused {
        _transferFromCaller(inputToken, inputAmount);

        // EXACT_BPT_IN_FOR_TOKENS_OUT = 1
        bytes memory userData = abi.encode(1, inputAmount);

        _approve(inputToken, address(vault));

        IBalancerVault(vault).exitPool(
            poolId,
            address(this),
            payable(recipient),
            IBalancerVault.ExitPoolRequest({
                assets: assets,
                minAmountsOut: minAmountsOut,
                userData: userData,
                toInternalBalance: false
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

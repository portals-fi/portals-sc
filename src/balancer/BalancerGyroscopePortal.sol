/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2024 Portals.fi

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
    /// @param recipient The recipient of the minted BPT
    function portalIn(
        address vault,
        bytes32 poolId,
        address recipient
    ) external payable whenNotPaused {
        address poolAddress = _getPoolAddress(poolId);

        uint256 poolSupply = ERC20(poolAddress).totalSupply();

        (address[] memory _tokens, uint256[] memory _balances,) =
            IBalancerVault(vault).getPoolTokens(poolId);

        uint256 bltOutAmount = 2 ** 255;

        uint256[] memory maxAmountsIn = new uint256[](_tokens.length);

        for (uint8 i = 0; i < _tokens.length; i++) {
            maxAmountsIn[i] = ERC20(_tokens[i]).balanceOf(msg.sender);

            _transferFromCaller(_tokens[i], maxAmountsIn[i]);
            _approve(_tokens[i], vault);

            uint256 newBltOutAmount = _bltOutAmount(
                maxAmountsIn[i], _balances[i], poolSupply
            );

            if (newBltOutAmount < bltOutAmount) {
                bltOutAmount = newBltOutAmount;
            }
        }

        // ALL_TOKENS_IN_FOR_EXACT_BPT_OUT = 3
        bytes memory userData = abi.encode(3, bltOutAmount);

        IBalancerVault(vault).joinPool(
            poolId,
            address(this),
            recipient,
            IBalancerVault.JoinPoolRequest({
                assets: _tokens,
                maxAmountsIn: maxAmountsIn,
                userData: userData,
                fromInternalBalance: false
            })
        );

        // Return dust to recipient
        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 dustBalance =
                ERC20(_tokens[i]).balanceOf(address(this));

            ERC20(_tokens[i]).transfer(recipient, dustBalance);
        }
    }

    function _bltOutAmount(
        uint256 maxAmountsIn,
        uint256 balance,
        uint256 poolSupply
    ) internal pure returns (uint256) {
        uint256 ratio =
            (maxAmountsIn * 1_000_000_000_000_000_000) / balance;
        uint256 bltOutAmount =
            ratio * poolSupply / 1_000_000_000_000_000_000;
        return bltOutAmount;
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

    function _getPoolAddress(bytes32 poolId)
        public
        pure
        returns (address)
    {
        // Extract the first 20 bytes of the poolId
        return address(uint160(uint256(poolId) >> 96));
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

/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2024 Portals.fi

/// @author Portals.fi
/// @notice This contract executes swaps on various DEXes
/// @note This contract is intended to be consumed via a multicall contract and as such omits various checks
/// including slippage. These checks should be handled by the caller. It is not recommended to interact with
/// this contract directly!

pragma solidity 0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Pausable } from
    "openzeppelin-contracts/security/Pausable.sol";
import { IUniswapV3Router } from "./interface/IUniswapV3Router.sol";
import { IBalancerV2Vault } from "./interface/IBalancerV2Vault.sol";

contract PortalsSwapExecutor is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    constructor(address admin) Owned(admin) { }

    /// @notice Swap tokens on Uniswap-V3 like DEXes
    /// @param inputToken The ERC20 token address to spend (address(0) if network token)
    /// @param inputAmount The quantity of inputToken to swap
    /// @param outputToken The ERC20 token address to buy (address(0) if network token)
    /// @param fee The fee tier to be used for the swap
    /// @param router The Uniswap V3-like router to be used for the swap
    /// @param recipient The recipient of the outputToken
    /// @return outputAmount The quantity of the output token received
    function swapUniswapV3Single(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint24 fee,
        IUniswapV3Router router,
        address recipient
    ) external payable whenNotPaused returns (uint256) {
        uint256 amount = _transferFromCaller(inputToken, inputAmount);
        _approve(inputToken, address(router));
        IUniswapV3Router.ExactInputSingleParams memory params =
        IUniswapV3Router.ExactInputSingleParams({
            tokenIn: inputToken,
            tokenOut: outputToken,
            fee: fee,
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        return router.exactInputSingle(params);
    }

    /// @notice Swap tokens on Uniswap-V3 like DEXes
    /// @param inputToken The ERC20 token address to spend (address(0) if network token)
    /// @param inputAmount The quantity of inputToken to swap
    /// @param path The swap path in the format (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut
    /// parameter is the shared token across the pools. For example abi.encodePacked(DAI, poolFee, USDC, poolFee, WETH9)
    /// @param router The Uniswap V3-like router to be used for the swap
    /// @param recipient The recipient of the outputToken
    /// @return outputAmount The quantity of the output token received
    function swapUniswapV3Multi(
        address inputToken,
        uint256 inputAmount,
        bytes memory path,
        IUniswapV3Router router,
        address recipient
    ) external payable whenNotPaused returns (uint256) {
        uint256 amount = _transferFromCaller(inputToken, inputAmount);
        _approve(inputToken, address(router));

        IUniswapV3Router.ExactInputParams memory params =
        IUniswapV3Router.ExactInputParams({
            path: path,
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0
        });

        return router.exactInput(params);
    }

    /// @notice Swap tokens on Balancer V2 like DEXes using batch swaps
    /// @param assets An array of ERC20 token addresses involved in the swaps
    /// @param inputAmount The quantity of the initial asset to swap
    /// @param swaps Array of `BatchSwapStep` structs detailing each swap step
    /// @param limits Limits for maximum tokens to send or minimum tokens to receive; modifies the first element to match input amount
    /// @param vault The Balancer V2 like Vault contract to interact with for swaps
    /// @param recipient The address that will receive the output token
    /// @return outputAmount The quantity of the output token received
    function swapBalancerV2Multi(
        address[] memory assets,
        uint256 inputAmount,
        IBalancerV2Vault.BatchSwapStep[] memory swaps,
        int256[] memory limits,
        IBalancerV2Vault vault,
        address payable recipient
    ) external payable whenNotPaused returns (uint256) {
        uint256 amount = _transferFromCaller(assets[0], inputAmount);
        _approve(assets[0], address(vault));

        IBalancerV2Vault.FundManagement memory funds =
        IBalancerV2Vault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: recipient,
            toInternalBalance: false
        });

        limits[0] = int256(amount);
        swaps[0].amount = amount;

        int256[] memory output = vault.batchSwap(
            IBalancerV2Vault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds,
            limits,
            block.timestamp
        );

        return uint256(-output[output.length - 1]);
    }

    /// @notice Swap tokens on Balancer V2 like DEXes using a single swap
    /// @param inputToken The ERC20 token address to spend (address(0) if network token)
    /// @param inputAmount The quantity of inputToken to swap
    /// @param outputToken The ERC20 token address to buy (address(0) if network token)
    /// @param poolId The Balancer V2 like pool identifier
    /// @param vault The Balancer V2 like Vault contract to interact with for swaps
    /// @param recipient The recipient of the outputToken
    /// @return outputAmount The quantity of the output token received
    function swapBalancerV2Single(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        bytes32 poolId,
        IBalancerV2Vault vault,
        address payable recipient
    ) external payable whenNotPaused returns (uint256) {
        uint256 amount = _transferFromCaller(inputToken, inputAmount);
        _approve(inputToken, address(vault));

        IBalancerV2Vault.SingleSwap memory singleSwap =
        IBalancerV2Vault.SingleSwap({
            poolId: poolId,
            kind: IBalancerV2Vault.SwapKind.GIVEN_IN,
            assetIn: inputToken,
            assetOut: outputToken,
            amount: amount,
            userData: ""
        });

        IBalancerV2Vault.FundManagement memory funds =
        IBalancerV2Vault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: recipient,
            toInternalBalance: false
        });

        return vault.swap(singleSwap, funds, 0, block.timestamp);
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

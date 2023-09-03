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
import { ISolidlyRouter } from "./interface/ISolidlyRouter.sol";
import { Babylonian } from "./lib/Babylonian.sol";

import { ISolidlyPool } from "./interface/ISolidlyPool.sol";

contract SolidlyPortal is Owned, Pausable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    uint256 internal constant BPS = 10_000;

    constructor(address admin) Owned(admin) { }

    /// @notice Add liquidity to Solidly-like pools with ERC20 tokens
    /// @param inputToken The ERC20 token address to spend
    /// @param inputAmount The quantity of inputToken to Portal in
    /// @param outputToken The pool (i.e. pair) address
    /// @param router The Solidly-like router to be used for adding liquidity
    /// @param stable True if pool is stable, false if volatile
    /// @param fee The swap fee for the pool in BPS
    /// @param recipient The recipient of the liquidity tokens
    function portalIn(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        ISolidlyRouter router,
        bool isVelodromeV2,
        bool stable,
        uint256 fee,
        address recipient
    ) external payable whenNotPaused {
        uint256 amount = _transferFromCaller(inputToken, inputAmount);

        _deposit(
            inputToken,
            amount,
            outputToken,
            router,
            isVelodromeV2,
            stable,
            fee,
            recipient
        );
    }

    /// @notice Sets up the correct token ratio and deposits into the pool
    /// @param inputToken The token address to swap from
    /// @param inputAmount The quantity of tokens to sell
    /// @param outputToken The pool (i.e. pair) address
    /// @param router The Solidly-like router to be used for adding liquidity
    /// @param isVelodromeV2 True if router is Velodrome V2-like, false otherwise
    /// @param stable True if pool is stable, false if volatile
    /// @param fee The swap fee for the pool in BPS
    /// @param recipient The recipient of the liquidity tokens
    function _deposit(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        ISolidlyRouter router,
        bool isVelodromeV2,
        bool stable,
        uint256 fee,
        address recipient
    ) internal {
        ISolidlyPool pool = ISolidlyPool(outputToken);

        (uint256 res0, uint256 res1,) = pool.getReserves();

        uint256 token0Amount;
        uint256 token1Amount;
        if (inputToken == pool.token0()) {
            uint256 swapAmount = stable
                ? _getSwapAmountStable(
                    pool.token0(),
                    inputAmount,
                    pool.token1(),
                    pool,
                    router,
                    isVelodromeV2,
                    stable
                )
                : _getSwapAmount(res0, inputAmount, fee);
            if (swapAmount == 0) swapAmount = inputAmount / 2;

            token1Amount = _intraSwap(
                inputToken,
                swapAmount,
                pool.token1(),
                router,
                isVelodromeV2,
                stable
            );

            token0Amount = inputAmount - swapAmount;
        } else {
            uint256 swapAmount = stable
                ? _getSwapAmountStable(
                    pool.token1(),
                    inputAmount,
                    pool.token0(),
                    pool,
                    router,
                    isVelodromeV2,
                    stable
                )
                : _getSwapAmount(res1, inputAmount, fee);
            if (swapAmount == 0) swapAmount = inputAmount / 2;

            token0Amount = _intraSwap(
                inputToken,
                swapAmount,
                pool.token0(),
                router,
                isVelodromeV2,
                stable
            );

            token1Amount = inputAmount - swapAmount;
        }

        _addLiquidity(
            pool.token0(),
            pool.token1(),
            token0Amount,
            token1Amount,
            router,
            stable,
            recipient
        );
    }

    /// @notice Adds liquidity to the pool
    /// @param token0 The first token in the pool
    /// @param token1 The second token in the pool
    /// @param token0Amount The quantity of token0 to add
    /// @param token1Amount The quantity of token1 to add
    /// @param router The Solidly-like router to be used for adding liquidity
    /// @param stable True if pool is stable, false if volatile
    /// @param recipient The recipient of the liquidity tokens
    function _addLiquidity(
        address token0,
        address token1,
        uint256 token0Amount,
        uint256 token1Amount,
        ISolidlyRouter router,
        bool stable,
        address recipient
    ) internal {
        _approve(token0, address(router));
        _approve(token1, address(router));

        (uint256 amount0Sent, uint256 amount1Sent,) = router
            .addLiquidity(
            token0,
            token1,
            stable,
            token0Amount,
            token1Amount,
            0,
            0,
            recipient,
            0xf000000000000000000000000000000000000000000000000000000000000000
        );
        if (token0Amount > amount0Sent) {
            ERC20(token0).safeTransfer(
                recipient, token0Amount - amount0Sent
            );
        }
        if (token1Amount > amount1Sent) {
            ERC20(token1).safeTransfer(
                recipient, token1Amount - amount1Sent
            );
        }
    }

    /// @notice Returns the optimal intra-pool swap quantity, for stable pools, such that
    /// that the proportion of both tokens held subsequent to the swap is
    /// equal to the proportion of the assets in the pool
    /// @param inputToken The ERC20 token address to swap from
    /// @param inputAmount The total quantity of tokens held
    /// @param outputToken The pool (i.e. pair) address
    /// @param pool The Solidly-like pool to use for the swap
    /// @param router The Solidly-like router to be used for adding liquidity
    /// @param isVelodromeV2 True if router is Velodrome V2-like, false otherwise
    /// @param stable True if pool is stable, false if volatile
    /// @return The quantity of the inputToken token to swap
    function _getSwapAmountStable(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        ISolidlyPool pool,
        ISolidlyRouter router,
        bool isVelodromeV2,
        bool stable
    ) internal view returns (uint256) {
        uint256 amountADesired = inputAmount / 2;
        uint256 amountBDesired =
            pool.getAmountOut(amountADesired, inputToken);
        uint256 token0Amount;
        uint256 token1Amount;
        if (isVelodromeV2) {
            (token0Amount, token1Amount,) = router.quoteAddLiquidity(
                inputToken,
                outputToken,
                stable,
                router.defaultFactory(),
                amountADesired,
                amountBDesired
            );
        } else {
            (token0Amount, token1Amount,) = router.quoteAddLiquidity(
                inputToken,
                outputToken,
                stable,
                amountADesired,
                amountBDesired
            );
        }
        uint256 token0Decimals = ERC20(inputToken).decimals();
        uint256 token1Decimals = ERC20(outputToken).decimals();

        token0Amount = token0Amount * 1e18 / 10 ** token0Decimals;
        token1Amount = token1Amount * 1e18 / 10 ** token1Decimals;

        amountBDesired = amountBDesired * 1e18 / 10 ** token1Decimals;
        amountADesired = amountADesired * 1e18 / 10 ** token0Decimals;

        uint256 ratio = amountBDesired * 1e18 / amountADesired
            * token0Amount / token1Amount;

        return inputAmount * 1e18 / (ratio + 1e18);
    }

    /// @notice Returns the optimal intra-pool swap quantity such that
    /// that the proportion of both tokens held subsequent to the swap is
    /// equal to the proportion of the assets in the pool
    /// @param reserves The reserves of the pool which inputToken belongs to
    /// @param inputAmount The total quantity of tokens held
    /// @param fee The swap fee for the pool in BPS
    /// @return The quantity of the inputToken token to swap
    function _getSwapAmount(
        uint256 reserves,
        uint256 inputAmount,
        uint256 fee
    ) internal pure returns (uint256) {
        return (
            Babylonian.sqrt(
                (
                    (2 * BPS - fee) * (2 * BPS - fee) * reserves
                        * reserves
                ) + (4 * (BPS - fee) * BPS * inputAmount * reserves)
            ) - (2 * BPS - fee) * (reserves)
        ) / (2 * (BPS - fee));
    }

    /// @notice Used for intra-pool swaps of ERC20 assets
    /// @param inputToken The token address to swap from
    /// @param inputAmount The quantity of tokens to sell
    /// @param outputToken The token address to swap to
    /// @param router The Velodrome V2-like router to use for the swap
    /// @return tokenBought The quantity of tokens bought
    function _intraSwap(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        ISolidlyRouter router,
        bool isVelodromeV2,
        bool stable
    ) internal returns (uint256) {
        if (inputToken == outputToken) {
            return inputAmount;
        }

        _approve(inputToken, address(router));

        ERC20 _outputToken = ERC20(outputToken);

        uint256 beforeSwap = _outputToken.balanceOf(address(this));
        if (isVelodromeV2) {
            ISolidlyRouter.VelodromeV2Route[] memory path =
                new ISolidlyRouter.VelodromeV2Route[](1);
            path[0] = ISolidlyRouter.VelodromeV2Route({
                from: inputToken,
                to: outputToken,
                stable: stable,
                factory: address(0)
            });

            router.swapExactTokensForTokens(
                inputAmount,
                0,
                path,
                address(this),
                0xf000000000000000000000000000000000000000000000000000000000000000
            );
        } else {
            ISolidlyRouter.SolidlyRoute[] memory path =
                new ISolidlyRouter.SolidlyRoute[](1);
            path[0] = ISolidlyRouter.SolidlyRoute({
                from: inputToken,
                to: outputToken,
                stable: stable
            });

            router.swapExactTokensForTokens(
                inputAmount,
                0,
                path,
                address(this),
                0xf000000000000000000000000000000000000000000000000000000000000000
            );
        }

        return _outputToken.balanceOf(address(this)) - beforeSwap;
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
}

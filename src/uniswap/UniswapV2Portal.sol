/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract adds or removes liquidity to/from Uniswap V2-like pools using/receiving
/// any ERC20 token or the network token.
/// @note This contract is intended to be consumed via a multicall contract and as such omits various checks
/// including slippage and does not return the quantity of tokens acquired. These checks should be handled
/// by the caller

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { Babylonian } from "./interface/Babylonian.sol";
import { IUniswapV2Factory } from "./interface/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "./interface/IUniswapV2Router.sol";
import { IUniswapV2Pair } from "./interface/IUniswapV2Pair.sol";
import { IWETH } from "./interface/IWETH.sol";

contract UniswapV2Portal is Owned {
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

    /// @notice Add liquidity to Uniswap V2-like pools with network tokens/ERC20 tokens
    /// @param sellToken The ERC20 token address to spend (address(0) if network token)
    /// @param sellAmount The quantity of sellToken to Portal in
    /// @param buyToken The pool (i.e. pair) address
    /// @param router The Uniswap V2-like router to be used for adding liquidity
    function portalIn(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        IUniswapV2Router02 router,
        address recipient
    ) external payable pausable {
        uint256 amount = _transferFromCaller(sellToken, sellAmount);

        _deposit(sellToken, amount, buyToken, router, recipient);
    }

    /// @notice Sets up the correct token ratio and deposits into the pool
    /// @param sellToken The token address to swap from
    /// @param sellAmount The quantity of tokens to sell
    /// @param buyToken The pool (i.e. pair) address
    /// @param router The Uniswap V2-like router to be used for adding liquidity
    /// @param recipient The recipient of the liquidity tokens
    function _deposit(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        IUniswapV2Router02 router,
        address recipient
    ) internal {
        IUniswapV2Pair pair = IUniswapV2Pair(buyToken);

        (uint256 res0, uint256 res1,) = pair.getReserves();

        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 token0Amount;
        uint256 token1Amount;

        if (sellToken == token0) {
            uint256 swapAmount = _getSwapAmount(res0, sellAmount);
            if (swapAmount <= 0) swapAmount = sellAmount / 2;

            token1Amount =
                _intraSwap(sellToken, swapAmount, token1, router);

            token0Amount = sellAmount - swapAmount;
        } else {
            uint256 swapAmount = _getSwapAmount(res1, sellAmount);
            if (swapAmount <= 0) swapAmount = sellAmount / 2;

            token0Amount =
                _intraSwap(sellToken, swapAmount, token0, router);

            token1Amount = sellAmount - swapAmount;
        }

        _approve(token0, address(router));
        _approve(token1, address(router));

        router.addLiquidity(
            token0,
            token1,
            token0Amount,
            token1Amount,
            0,
            0,
            recipient,
            block.timestamp
        );
    }

    /// @notice Returns the optimal intra-pool swap quantity such that
    /// that the proportion of both tokens held subsequent to the swap is
    /// equal to the proportion of the assets in the pool. Assumes typical
    /// Uniswap V2 fee.
    /// @param reserves The reserves of the sellToken
    /// @param amount The total quantity of tokens held
    /// @return The quantity of the sell token to swap
    function _getSwapAmount(uint256 reserves, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (
            Babylonian.sqrt(
                reserves
                    * ((amount * 3_988_000) + (reserves * 3_988_009))
            ) - (reserves * 1997)
        ) / 1994;
    }

    /// @notice Used for intra-pool swaps of ERC20 assets
    /// @param sellToken The token address to swap from
    /// @param sellAmount The quantity of tokens to sell
    /// @param buyToken The token address to swap to
    /// @param router The Uniswap V2-like router to use for the swap
    /// @return tokenBought The quantity of tokens bought
    function _intraSwap(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        IUniswapV2Router02 router
    ) internal returns (uint256) {
        if (sellToken == buyToken) {
            return sellAmount;
        }

        _approve(sellToken, address(router));

        address[] memory path = new address[](2);
        path[0] = sellToken;
        path[1] = buyToken;

        uint256 beforeSwap = _getBalance(address(this), buyToken);

        router.swapExactTokensForTokens(
            sellAmount, 1, path, address(this), block.timestamp
        );

        return _getBalance(address(this), buyToken) - beforeSwap;
    }

    /// @notice Transfers tokens or the network token from the caller to this contract
    /// @param token The address of the token to transfer (address(0) if network token)
    /// @param quantity The quantity of tokens to transfer from the caller
    /// @dev quantity must == msg.value when token == address(0)
    /// @dev msg.value must == 0 when token != address(0)
    /// @return The quantity of tokens or network tokens transferred from the caller to this contract
    function _transferFromCaller(address token, uint256 quantity)
        internal
        virtual
        returns (uint256)
    {
        if (token == address(0)) {
            require(
                msg.value > 0 && msg.value == quantity,
                "Invalid quantity or msg.value"
            );

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

    /// @notice Get the token or network token balance of an account
    /// @param account The owner of the tokens or network tokens whose balance is being queried
    /// @param token The address of the token (address(0) if network token)
    /// @return The owner's token or network token balance
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

    /// @dev Pause or unpause the contract
    function pause() external onlyOwner {
        paused = !paused;
        emit Pause(paused);
    }

    /// @notice Reverts if networks tokens are sent directly to this contract
    receive() external payable {
        require(msg.sender != tx.origin);
    }
}

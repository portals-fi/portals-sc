// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ISolidlyRouter {
    /// @notice Add liquidity of two tokens to a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @param amountAMin       Minimum amount of tokenA to deposit
    /// @param amountBMin       Minimum amount of tokenB to deposit
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount deposited into a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param _factory         Address of PoolFactory for tokenA and tokenB
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    )
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount deposited into a Solidly Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired
    )
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Swap one token for another on Velodrome V2
    /// @param amountIn         Amount of token in
    /// @param amountOutMin     Minimum amount of desired token received
    /// @param routes           Array of trade routes used in the swap
    /// @param to               Recipient of the tokens received
    /// @param deadline         Deadline to receive tokens
    /// @return amounts         Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        VelodromeV2Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap one token for another on Solidly
    /// @param amountIn         Amount of token in
    /// @param amountOutMin     Minimum amount of desired token received
    /// @param routes           Array of trade routes used in the swap
    /// @param to               Recipient of the tokens received
    /// @param deadline         Deadline to receive tokens
    /// @return amounts         Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        SolidlyRoute[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @dev Returns the address of the default factory for the router.
    function defaultFactory() external pure returns (address);

    /// @notice                 Struct describing the route of a token swap on Velodrome V2
    /// @param from             Address of token to swap from
    /// @param to               Address of token to swap to
    /// @param stable           True if pool is stable, false if volatile
    /// @param factory          Address of factory to use for swap (address(0) for default factory)
    struct VelodromeV2Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    /// @notice                 Struct describing the route of a token swap on Solidly
    /// @param from             Address of token to swap from
    /// @param to               Address of token to swap to
    /// @param stable           True if pool is stable, false if volatile
    /// @param factory          Address of factory to use for swap (address(0) for default factory)
    struct SolidlyRoute {
        address from;
        address to;
        bool stable;
    }
}

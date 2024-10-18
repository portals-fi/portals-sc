// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ISolidlyPool {
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

    /// @notice Get the token reserves of the pool
    /// @return _reserve0       Amount of token0 in the pool
    /// @return _reserve1       Amount of token1 in the pool
    /// @return _blockTimestampLast  Block timestamp of last update
    function getReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        );

    /// @notice Get the amount of tokenOut given the amount of tokenIn
    /// @param amountIn Amount of token in
    /// @param tokenIn  Address of token
    /// @return Amount out
    function getAmountOut(uint256 amountIn, address tokenIn)
        external
        view
        returns (uint256);

    /// @dev Returns the address of the pair token with the lower sort order.
    function token0() external pure returns (address);

    /// @dev Returns the address of the pair token with the higher sort order.
    function token1() external pure returns (address);

    /// @dev Returns the address of the factory for the pool.
    function factory() external pure returns (address);

    // Used to denote stable or volatile pools
    function stable() external pure returns (bool);
}

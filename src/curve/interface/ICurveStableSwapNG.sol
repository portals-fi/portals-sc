// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ICurveStableSwapNG {
    /*
     * @notice Deposit coins into the pool
     * @param _amounts List of amounts of coins to deposit
     * @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
     * @param _receiver Address that owns the minted LP tokens
     * @return Amount of LP tokens received by depositing
     */
    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);

    // Get the number of tokens in the pool
    function N_COINS() external returns (uint256);
}

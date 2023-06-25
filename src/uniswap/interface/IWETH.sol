// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IWETH {
    /// @dev Deposits ETH into the contract, creating wrapped ETH (WETH) and returning it to the caller.
    function deposit() external payable;

    /// @dev Withdraws ETH from the contract, sending it to the caller in exchange for an equivalent amount of WETH.
    function withdraw(uint256 wad) external;
}

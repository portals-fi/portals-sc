// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBalancerQueries {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData; // 0x for most swaps
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function getPoolId() external view returns (bytes32);

    function querySwap(
        SingleSwap memory singleSwap,
        FundManagement memory funds
    ) external returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { ISolidlyRouter } from "./ISolidlyRouter.sol";

interface ISolidlyPortal {
    /// @notice Struct describing the Solidly specific params for SolidlyPortal
    /// @param router The Solidly-like router to be used for adding liquidity
    /// @param isVelodromeV2 True if router is Velodrome V2-like, false otherwise
    /// @param stable True if pool is stable, false if volatile
    /// @param fee The swap fee for the pool in BPS
    /// @param gauge The address of gauge to stake (address(0) to skip staking)
    struct SolidlyParams {
        ISolidlyRouter router;
        bool isVelodromeV2;
        bool stable;
        uint256 fee;
        address gauge;
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { ISolidlyRouter } from "./ISolidlyRouter.sol";

interface IVelodromeV2Gauge {
    /// @notice Deposit LP tokens into gauge for any user
    /// @param _amount The quantity of LP tokens to deposit
    /// @param _recipient The address to deposit LP tokens for
    function deposit(uint256 _amount, address _recipient) external;
}

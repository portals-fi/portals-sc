/// Copyright (C) 2022 Portals.fi

/// @author Portals.fi
/// @notice Interface for the Base contract inherited by Portals

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IRouterBase {
    /// @notice Emitted when the fee is changed
    /// @param fee The old new in BPS
    event Fee(uint256 fee);

    /// @notice Emitted when/if the router is paused
    /// @param paused The active status of this contract. If false, contract is
    /// active (i.e un-paused)
    event Pause(bool paused);
}

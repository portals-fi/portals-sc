/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract emits a bootstrap event for use with subgraphs

pragma solidity 0.8.19;

import { AccessControl } from
    "openzeppelin-contracts/access/AccessControl.sol";

contract GraphBootstrapper is AccessControl {
    event Bootstrap();

    bytes32 public constant BOOTSTRAP_ROLE =
        keccak256("BOOTSTRAP_ROLE");

    constructor(address admin, address[] memory devs) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        for (uint256 i = 0; i < devs.length; i++) {
            _grantRole(BOOTSTRAP_ROLE, devs[i]);
        }
    }

    function bootstrap()
        external
        payable
        onlyRole((BOOTSTRAP_ROLE))
    {
        emit Bootstrap();
    }
}

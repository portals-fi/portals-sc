/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract bundles multiple methods into a single transaction.
/// @dev Do not grant approvals to this contract unless they are completely
/// consumed or are revoked at the end of the transaction.

/// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import { IPortalsMulticall } from
    "../multicall/interface/IPortalsMulticall.sol";
import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract PortalsMulticall is IPortalsMulticall, ReentrancyGuard {
    /// @dev Executes a series of calls in a single transaction
    /// @param calls The calls to execute
    function aggregate(Call[] calldata calls)
        external
        payable
        nonReentrant
    {
        for (uint256 i = 0; i < calls.length;) {
            IPortalsMulticall.Call memory call = calls[i];
            uint256 balance;
            uint256 value;
            if (call.sellToken == address(0)) {
                value = address(this).balance;
                _setAmount(call.data, call.amountIndex, value);
            } else {
                balance =
                    ERC20(call.sellToken).balanceOf(address(this));
                _setAmount(call.data, call.amountIndex, balance);
            }

            (bool success, bytes memory returnData) =
                call.target.call{ value: value }(call.data);
            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (returnData.length < 68) {
                    revert("PortalsMulticall: failed");
                }
                assembly {
                    returnData := add(returnData, 0x04)
                }
                revert(abi.decode(returnData, (string)));
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Transfers ETH from this contract to the specified address
    /// @param to The address to transfer ETH to
    /// @param amount The quantity of ETH to transfer
    function transferEth(address to, uint256 amount) public payable {
        (bool success,) = to.call{ value: amount }("");
        require(success, "PortalsMulticall: failed to transfer ETH");
    }

    /// @dev Sets the quantity of a token a specified index in the data
    /// @param data The data to set the quantity in
    /// @param amountIndex The index of the quantity of sellToken in the data
    function _setAmount(
        bytes memory data,
        uint256 amountIndex,
        uint256 amount
    ) private pure {
        if (amountIndex == type(uint256).max) return;
        assembly {
            mstore(add(data, add(36, mul(amountIndex, 32))), amount)
        }
    }

    /// @notice Reverts if network tokens are sent directly to this contract
    receive() external payable {
        require(msg.sender != tx.origin);
    }
}

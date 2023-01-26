/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IPortalsMulticall {
    struct Call {
        address sellToken;
        uint256 value;
        address target;
        bytes data;
        uint256 amountIndex;
    }

    function aggregate(Call[] calldata calls) external payable;
}

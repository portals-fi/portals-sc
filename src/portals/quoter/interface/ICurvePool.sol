// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICurvePool {
    function get_dy(int128 i, int128 j, uint256 dx)
        external
        view
        returns (uint256 out);

    function get_dy_underlying(int128 i, int128 j, uint256 dx)
        external
        view
        returns (uint256 out);

    function coins(uint256 arg0)
        external
        view
        returns (address out);
}

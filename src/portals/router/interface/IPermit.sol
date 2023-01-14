/// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

//@param owner The address which is a source of funds and has signed the Permit.
//@param spender The address which is allowed to spend the funds.
//@param value The quantity of tokens to be spent.
//@param deadline The timestamp after which the Permit is no longer valid.
//@param signature A valid secp256k1 signature of Permit by owner encoded as r,
// s, v.
interface IPermit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    //@param owner The address which is a source of funds and has signed the
    // Permit.
    //@param spender The address which is allowed to spend the funds.
    //@param amount The amount of tokens to be spent.
    //@param expiry The timestamp after which the Permit is no longer valid.
    //@param signature A valid secp256k1 signature of Permit by owner encoded as
    // r, s, v.
    // @return True, if transaction completes successfully
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 expiry,
        bytes calldata signature
    ) external returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { IPortalsRouter } from
    "../../src/portals/router/interface/IPortalsRouter.sol";

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant DAI_PERMIT_TYPEHASH =
        0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    //EIP712 Order Typehash
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        abi.encodePacked(
            "Order(address inputToken,uint256 inputAmount,address outputToken,uint256 minOutputAmount,address feeToken,uint256 fee,address recipient,address partner)"
        )
    );

    //EIP712 Signed Order Typehash
    bytes32 public constant SIGNED_ORDER_TYPEHASH = keccak256(
        abi.encodePacked(
            "SignedOrder(Order order,bytes32 routeHash,address sender,uint64 deadline,uint64 nonce)Order(address inputToken,uint256 inputAmount,address outputToken,uint256 minOutputAmount,address feeToken,uint256 fee,address recipient,address partner)"
        )
    );

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    struct DaiPermit {
        address holder;
        address spender;
        uint256 nonce;
        uint256 expiry;
        bool allowed;
    }

    // computes the hash of a permit
    function getPermitStructHash(Permit memory _permit)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
    }

    // computes the hash of a DAI permit
    function getDaiPermitStructHash(DaiPermit memory _daiPermit)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                DAI_PERMIT_TYPEHASH,
                _daiPermit.holder,
                _daiPermit.spender,
                _daiPermit.nonce,
                _daiPermit.expiry,
                _daiPermit.allowed
            )
        );
    }

    function getSignedOrderStructHash(
        IPortalsRouter.SignedOrder memory _signedOrder
    ) internal pure returns (bytes32) {
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                _signedOrder.order.inputToken,
                _signedOrder.order.inputAmount,
                _signedOrder.order.outputToken,
                _signedOrder.order.minOutputAmount,
                _signedOrder.order.feeToken,
                _signedOrder.order.fee,
                _signedOrder.order.recipient,
                _signedOrder.order.partner
            )
        );
        return keccak256(
            abi.encode(
                SIGNED_ORDER_TYPEHASH,
                orderHash,
                _signedOrder.routeHash,
                _signedOrder.sender,
                _signedOrder.deadline,
                _signedOrder.nonce
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getPermitTypedDataHash(Permit memory _permit)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                getPermitStructHash(_permit)
            )
        );
    }

    function getDaiPermitTypedDataHash(DaiPermit memory _daiPermit)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                getDaiPermitStructHash(_daiPermit)
            )
        );
    }

    function getSignedOrderTypedDataHash(
        IPortalsRouter.SignedOrder memory _signedOrder
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                getSignedOrderStructHash(_signedOrder)
            )
        );
    }
}

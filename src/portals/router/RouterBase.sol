/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice Base contract inherited by the Portals Router

/// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import { IRouterBase } from "./interface/IRouterBase.sol";
import { IPortalsRouter } from "./interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../multicall/interface/IPortalsMulticall.sol";
import { IPermit } from "./interface/IPermit.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { SignatureChecker } from
    "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

abstract contract RouterBase is IRouterBase, Owned {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// Thrown when insufficient liquidity is received after deposit or
    /// withdrawal
    /// @param buyAmount The amount of liquidity received
    /// @param minBuyAmount The minimum acceptable quantity of liquidity
    /// received
    error InsufficientBuy(uint256 buyAmount, uint256 minBuyAmount);

    /// @notice Emitted when portalling
    /// @param sellToken The ERC20 token address to spend (address(0) if network
    /// token)
    /// @param sellAmount The quantity of sellToken to Portal out
    /// @param buyToken The ERC20 token address to buy (address(0) if network
    /// token)
    /// @param buyAmount The quantity of buyToken received
    /// @param fee The fee in BPS
    /// @param sender The  msg.sender
    /// @param partner The front end operator address
    event Portal(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        uint256 buyAmount,
        uint256 baseFee,
        uint256 fee,
        address indexed sender,
        address indexed recipient,
        address indexed partner
    );

    // The Portals Multicall contract
    IPortalsMulticall public immutable PORTALS_MULTICALL;

    // Active status of this contract. If false, contract is active (i.e
    // un-paused)
    bool public paused;

    // The minimum fee in basis points (bps)
    uint256 public baseFee;

    // The address of the fee collector
    address public collector;

    // Circuit breaker
    modifier pausable() {
        require(!paused, "Paused");
        _;
    }

    //EIP-712 variables:
    //Contract name
    string private name = "PortalsRouter";

    //Contract version
    string public constant version = "1";

    //EIP712 Domain Typehash
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        )
    );

    //EIP712 Order Typehash
    bytes32 internal constant ORDER_TYPEHASH = keccak256(
        abi.encodePacked(
            "Order(address sellToken,uint256 sellAmount,address buyToken,uint256 minBuyAmount,uint256 fee,adress recipient,address partner)"
        )
    );

    //EIP712 Signed Order Typehash
    bytes32 internal constant SIGNED_ORDER_TYPEHASH = keccak256(
        abi.encodePacked(
            "SignedOrder(Order order,address sender,uint256 deadline,uint32 nonce,address broadcaster,uint256 gasFee)Order(address sellToken,uint256 sellAmount,address buyToken,uint256 minBuyAmount,uint256 fee,adress recipient,address partner)"
        )
    );

    //EIP712 Domain Separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    //Order nonces
    mapping(address => uint256) public nonces;

    //Permit Typehash
    bytes32 internal constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    constructor(
        address _admin,
        uint256 _baseFee,
        address _collector,
        address _multicall
    ) Owned(_admin) {
        collector = _collector;
        baseFee = _baseFee;
        PORTALS_MULTICALL = IPortalsMulticall(_multicall);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Transfers tokens or the network token from the sender to the
    /// Portals multicall contract after accounting for the fee
    /// @param sender The address of the owner of the tokens
    /// @param token The address of the token to transfer (address(0) if network
    /// token)
    /// @param quantity The quantity of tokens to transfer from the caller
    /// @dev quantity must == msg.value when token == address(0)
    /// @dev msg.value must == 0 when token != address(0)
    /// @param fee The fee in BPS
    /// @return value The quantity of network tokens to be transferred to the Portals
    /// multicall contract
    function _transferFromSender(
        address sender,
        address token,
        uint256 quantity,
        uint256 fee
    ) internal returns (uint256) {
        require(
            fee >= baseFee && fee <= 100, "PortalsRouter: Invalid fee"
        );
        if (token == address(0)) {
            require(
                quantity == msg.value && msg.value > 0,
                "Invalid quantity or msg.value"
            );
            if (fee == 0) return msg.value;
            uint256 ethAmount = _getFeeAmount(msg.value, fee);
            collector.safeTransferETH(ethAmount);
            return msg.value - ethAmount;
        }

        require(
            quantity > 0 && msg.value == 0,
            "PortalsRouter: Invalid quantity or msg.value"
        );
        if (fee == 0) {
            ERC20(token).safeTransferFrom(
                sender, address(PORTALS_MULTICALL), quantity
            );
            return 0;
        }

        uint256 tokenAmount = _getFeeAmount(quantity, fee);
        ERC20(token).safeTransferFrom(sender, collector, tokenAmount);
        ERC20(token).safeTransferFrom(
            sender, address(PORTALS_MULTICALL), quantity - tokenAmount
        );

        return 0;
    }

    /// @notice Transfers the gasFee from the sender to the broadcaster in the `token` currency
    /// @param sender is the address of the owner of the tokens
    /// @param token The address of the token to transfer
    /// @param quantity The quantity of tokens to transfer from the sender for gas
    /// @param broadcaster The address of the broadcaster
    /// @param gasFee The quantity of tokens to transfer to the broadcaster
    /// @return remainder The quantity of tokens remaining after the transfer
    function _transferGasFee(
        address sender,
        address token,
        uint256 quantity,
        address broadcaster,
        uint256 gasFee
    ) internal returns (uint256 remainder) {
        if (gasFee == 0) return quantity;
        ERC20(token).safeTransferFrom(sender, broadcaster, gasFee);
        remainder = quantity - gasFee;
    }

    /// @notice Calculates the fee amount
    /// @param quantity The quantity of tokens to subtract the fee from
    /// @return The fee amount
    function _getFeeAmount(uint256 quantity, uint256 fee)
        private
        pure
        returns (uint256)
    {
        return (quantity * fee) / 10_000;
    }

    /// @notice Get the token or network token balance of an account
    /// @param account The owner of the tokens or network tokens whose balance
    /// is being queried
    /// @param token The address of the token (address(0) if network token)
    /// @return The owner's token or network token balance
    function _getBalance(address account, address token)
        internal
        view
        returns (uint256)
    {
        if (token == address(0)) {
            return account.balance;
        } else {
            return ERC20(token).balanceOf(account);
        }
    }

    function _verify(
        IPortalsRouter.SignedOrderPayload calldata signedOrderPayload
    ) internal {
        IPortalsRouter.SignedOrder calldata signedOrder =
            signedOrderPayload.signedOrder;
        require(
            signedOrderPayload.signedOrder.deadline >= block.timestamp,
            "PortalsRouter: Order expired"
        );
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                signedOrder.order.sellToken,
                signedOrder.order.sellAmount,
                signedOrder.order.buyToken,
                signedOrder.order.minBuyAmount,
                signedOrder.order.fee,
                signedOrder.order.recipient,
                signedOrder.order.partner
            )
        );
        bytes32 signedOrderHash = keccak256(
            abi.encode(
                SIGNED_ORDER_TYPEHASH,
                orderHash,
                signedOrder.sender,
                signedOrder.deadline,
                nonces[signedOrder.sender]++
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR, signedOrderHash
            )
        );

        require(
            SignatureChecker.isValidSignatureNow(
                signedOrder.sender,
                digest,
                signedOrderPayload.signature
            ),
            "PortalsRouter: Invalid signature"
        );
    }

    function _permit(
        address token,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) internal {
        if (permitPayload.splitSignature) {
            bytes memory signature = permitPayload.signature;
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            IPermit(token).permit(
                permitPayload.owner,
                address(this),
                permitPayload.amount,
                permitPayload.deadline,
                v,
                r,
                s
            );
        } else {
            IPermit(token).permit(
                permitPayload.owner,
                address(this),
                permitPayload.amount,
                permitPayload.deadline,
                permitPayload.signature
            );
        }
    }

    /// @dev Pause or unpause the contract
    function pause() external onlyOwner {
        paused = !paused;
        emit Pause(paused);
    }

    /// @notice Sets the minimum fee
    /// @param _fee The new fee amount (less than 100 or 1%)
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Invalid Fee");
        baseFee = _fee;
        emit Fee(_fee);
    }
}

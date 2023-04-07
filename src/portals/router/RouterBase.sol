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

    // The Portals Multicall contract
    IPortalsMulticall public Portals_Multicall;

    // Active status of this contract. If false, contract is active (i.e un-paused)
    bool public paused;

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
            "Order(address sellToken,uint256 sellAmount,address buyToken,uint256 minBuyAmount,address feeToken,uint256 fee,adress recipient,address partner)"
        )
    );

    //EIP712 Signed Order Typehash
    bytes32 internal constant SIGNED_ORDER_TYPEHASH = keccak256(
        abi.encodePacked(
            "SignedOrder(Order order,address sender,uint256 deadline,uint32 nonce)Order(address sellToken,uint256 sellAmount,address buyToken,uint256 minBuyAmount,address feeToken,uint256 fee,adress recipient,address partner)"
        )
    );

    //EIP712 Domain Separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    //Order nonces
    mapping(address => uint64) public nonces;

    constructor(
        address _admin,
        address _collector,
        address _multicall
    ) Owned(_admin) {
        collector = _collector;
        Portals_Multicall = IPortalsMulticall(_multicall);
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

    /// @notice Transfers tokens or the network token from the sender to the Portals multicall contract
    /// @param sender The address of the owner of the tokens
    /// @param token The address of the token to transfer (address(0) if network token)
    /// @param quantity The quantity of tokens to transfer from the caller
    /// @return value The quantity of network tokens to be transferred to the Portals Multicall contract
    function _transferFromSender(
        address sender,
        address token,
        uint256 quantity
    ) internal returns (uint256) {
        if (token == address(0)) {
            require(msg.value > 0, "PortalsRouter: Invalid msg.value");
            return msg.value;
        }

        require(
            msg.value == 0 && quantity > 0,
            "PortalsRouter: Invalid quantity or msg.value"
        );
        ERC20(token).safeTransferFrom(
            sender, address(Portals_Multicall), quantity
        );
        return 0;
    }

    /// @notice Get the ERC20 or network token balance of an account
    /// @param account The owner of the tokens or network tokens whose balance is being queried
    /// @param token The address of the token (address(0) if network token)
    /// @return The accounts's token or network token balance
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

    /// @notice Signature verification function to verify Portals signed orders. Supports both ECDSA
    /// signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets
    /// @dev Returns nothing if the order is valid but reverts if the signature is invalid
    /// @param signedOrder The signed order to verify
    /// @param signature The signature of the signed order
    function _verify(
        IPortalsRouter.SignedOrder calldata signedOrder,
        bytes calldata signature
    ) internal {
        require(
            signedOrder.deadline >= block.timestamp,
            "PortalsRouter: Order expired"
        );
        bytes32 orderHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                signedOrder.order.sellToken,
                signedOrder.order.sellAmount,
                signedOrder.order.buyToken,
                signedOrder.order.minBuyAmount,
                signedOrder.order.feeToken,
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
                signedOrder.sender, digest, signature
            ),
            "PortalsRouter: Invalid signature"
        );
    }

    /// @notice Permit function for gasless approvals. Supports both EIP-2612 and DAI style permits with
    /// split signatures, as well as Yearn like permits with combined signatures
    /// @param token The address of the token to permit
    /// @param permitPayload The permit payload containing the permit parameters
    /// @dev See IPermit.sol for more details
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
            if (permitPayload.daiPermit) {
                IPermit(token).permit(
                    permitPayload.owner,
                    address(this),
                    ERC20(token).nonces(permitPayload.owner),
                    permitPayload.deadline,
                    true,
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
                    v,
                    r,
                    s
                );
            }
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

    /// @dev Updates the collector
    /// @param _collector The new collector
    function setCollector(address _collector) external onlyOwner {
        require(
            _collector != address(0),
            "PortalsRouter: Invalid collector"
        );
        collector = _collector;
        emit Collector(_collector);
    }

    /// @dev Updates the multicall
    /// @param multicall The new collector
    function setMulticall(address multicall) external onlyOwner {
        require(
            multicall != address(0),
            "PortalsRouter: Invalid multicall"
        );
        Portals_Multicall = IPortalsMulticall(multicall);
        emit Multicall(multicall);
    }

    /// @notice Invalidates the next order of msg.sender
    /// @notice Orders that have already been confirmed are not invalidated
    function invalidateNextOrder() external {
        nonces[msg.sender] = nonces[msg.sender] + 1;
    }

    /// @notice Recovers stuck tokens and sends them to the collector
    /// @param tokenAddress The address of the token to recover (address(0) if ETH)
    /// @param tokenAmount The quantity of tokens to recover
    function recoverToken(address tokenAddress, uint256 tokenAmount)
        external
    {
        if (tokenAddress == address(0)) {
            collector.safeTransferETH(tokenAmount);
        } else {
            ERC20(tokenAddress).safeTransfer(collector, tokenAmount);
        }
    }
}

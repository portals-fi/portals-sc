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
    mapping(address => uint64) public nonces;

    constructor(
        address _admin,
        uint256 _baseFee,
        address _collector,
        address _multicall
    ) Owned(_admin) {
        collector = _collector;
        baseFee = _baseFee;
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

    /// @notice Transfers tokens or the network token from the sender to the
    /// Portals multicall contract after accounting for the fee
    /// @param sender The address of the owner of the tokens
    /// @param token The address of the token to transfer (address(0) if network
    /// token)
    /// @param quantity The quantity of tokens to transfer from the caller
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
            fee >= baseFee && fee < 101, "PortalsRouter: Invalid fee"
        );
        if (token == address(0)) {
            require(msg.value > 0, "PortalsRouter: Invalid msg.value");
            if (fee == 0) return msg.value;
            uint256 ethAmount = _getFeeAmount(msg.value, fee);
            collector.safeTransferETH(ethAmount);
            return msg.value - ethAmount;
        }

        require(
            msg.value == 0 && quantity > 0,
            "PortalsRouter: Invalid quantity or msg.value"
        );
        if (fee == 0) {
            ERC20(token).safeTransferFrom(
                sender, address(Portals_Multicall), quantity
            );
            return 0;
        }

        ERC20 _token = ERC20(token);
        uint256 tokenAmount = _getFeeAmount(quantity, fee);
        _token.safeTransferFrom(sender, collector, tokenAmount);
        _token.safeTransferFrom(
            sender, address(Portals_Multicall), quantity - tokenAmount
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
                nonces[signedOrder.sender]++,
                signedOrder.broadcaster,
                signedOrder.gasFee
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

    /// @notice Sets the minimum fee
    /// @param _fee The new fee amount (less than 100 or 1%)
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Invalid Fee");
        baseFee = _fee;
        emit Fee(_fee);
    }

    /// @notice Updates the collector
    /// @param _collector The new collector
    function setCollector(address _collector) external onlyOwner {
        require(
            _collector != address(0),
            "PortalsRouter: Invalid collector"
        );
        collector = _collector;
        emit Collector(_collector);
    }

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

    /// @notice Recovers stuck tokens
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

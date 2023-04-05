/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract routes ERC20 and native tokens to the Portals Multicall contract to
/// transform a sell token into a minimum quantity of a buy token.

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IPortalsRouter } from "./interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../multicall/interface/IPortalsMulticall.sol";
import { RouterBase } from "./RouterBase.sol";

contract PortalsRouter is RouterBase {
    constructor(
        address _admin,
        address _collector,
        address _multicall
    ) RouterBase(_admin, _collector, _multicall) { }

    /// @notice This function is the simplest entry point for the Portals Router. It is intended
    /// to be called by the sender of the order (i.e. msg.sender).
    /// @param order The order struct containing the details of the trade
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param buyAmount The quantity of buyToken received after validation of the order
    function portal(
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls
    ) public payable pausable returns (uint256 buyAmount) {
        return _execute(
            msg.sender,
            order,
            calls,
            _transferFromSender(
                msg.sender, order.sellToken, order.sellAmount
            )
        );
    }

    /// @notice This function calls permit prior to the portal function for gasless approvals. It is intended
    /// to be called by the sender of the order (i.e. msg.sender).
    /// @param order The order struct containing the details of the trade
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param permitPayload The permit payload struct containing the details of the permit
    /// @param buyAmount The quantity of buyToken received after validation of the order
    function portalWithPermit(
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external pausable returns (uint256 buyAmount) {
        _permit(order.sellToken, permitPayload);
        return portal(order, calls);
    }

    /// This function uses Portals signed orders to facilitate gasless portals. It is intended
    /// to be called by a broadcaster (i.e. msg.sender != order.sender).
    /// @param signedOrderPayload The signed order payload struct containing the details of the signed order
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param buyAmount The quantity of buyToken received after validation of the order
    function portalWithSignature(
        IPortalsRouter.SignedOrderPayload calldata signedOrderPayload,
        IPortalsMulticall.Call[] calldata calls
    ) public pausable returns (uint256 buyAmount) {
        _verify(signedOrderPayload);
        IPortalsRouter.SignedOrder calldata signedOrder =
            signedOrderPayload.signedOrder;
        return _execute(
            signedOrder.sender,
            signedOrder.order,
            calls,
            _transferFromSender(
                signedOrder.sender,
                signedOrder.order.sellToken,
                signedOrder.order.sellAmount
            )
        );
    }

    /// @notice This function calls permit prior to the portalWithSignature function for gasless approvals,
    /// in addition to gassless Portals. It is intended to be called by a broadcaster (i.e. msg.sender != order.sender).
    /// @param signedOrderPayload The signed order payload struct containing the details of the signed order
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param permitPayload The permit payload struct containing the details of the permit
    /// @param buyAmount The quantity of buyToken received after validation of the order
    function portalWithSignatureAndPermit(
        IPortalsRouter.SignedOrderPayload calldata signedOrderPayload,
        IPortalsMulticall.Call[] calldata calls,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external pausable returns (uint256 buyAmount) {
        _permit(
            signedOrderPayload.signedOrder.order.sellToken,
            permitPayload
        );

        return portalWithSignature(signedOrderPayload, calls);
    }

    /// @notice This function executes calls to transform a sell token into a buy token.
    /// The buyAmount of the buyToken specified in the order is validated against the minBuyAmount following the
    /// aggregate call of Portals Multicall.
    /// @param sender The sender(signer) of the order
    /// @param order The order struct containing the details of the trade
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param value The value of native tokens to be sent to the Portals Multicall
    /// @param buyAmount The quantity of buyToken received after validation of the order
    function _execute(
        address sender,
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls,
        uint256 value
    ) private returns (uint256 buyAmount) {
        uint256 collected;
        collected = _getBalance(collector, order.feeToken);
        buyAmount = _getBalance(order.recipient, order.buyToken);

        Portals_Multicall.aggregate{ value: value }(calls);

        buyAmount =
            _getBalance(order.recipient, order.buyToken) - buyAmount;

        if (buyAmount < order.minBuyAmount) {
            revert InsufficientBuy(buyAmount, order.minBuyAmount);
        }

        require(
            _getBalance(collector, order.feeToken) - collected
                == order.fee,
            "PortalsRouter: Invalid fee"
        );

        emit Portal(
            order.sellToken,
            order.sellAmount,
            order.buyToken,
            buyAmount,
            order.feeToken,
            order.fee,
            sender,
            order.recipient,
            order.partner
            );
    }
}

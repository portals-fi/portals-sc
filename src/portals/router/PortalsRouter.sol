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
    constructor(address _admin, address _multicall)
        RouterBase(_admin, _multicall)
    { }

    /// @notice This function is the simplest entry point for the Portals Router. It is intended
    /// to be called by the sender of the order (i.e. msg.sender).
    /// @param orderPayload The order payload containing the details of the trade
    /// @return outputAmount The quantity of outputToken received after validation of the order
    function portal(IPortalsRouter.OrderPayload calldata orderPayload)
        public
        payable
        pausable
        returns (uint256 outputAmount)
    {
        return _execute(
            msg.sender,
            orderPayload.order,
            orderPayload.calls,
            _transferFromSender(
                msg.sender,
                orderPayload.order.inputToken,
                orderPayload.order.inputAmount
            )
        );
    }

    /// @notice This function calls permit prior to the portal function for gasless approvals. It is intended
    /// to be called by the sender of the order (i.e. msg.sender).
    /// @param orderPayload The order payload containing the details of the trade
    /// @param permitPayload The permit payload struct containing the details of the permit
    /// @return outputAmount The quantity of outputToken received after validation of the order
    function portalWithPermit(
        IPortalsRouter.OrderPayload calldata orderPayload,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external pausable returns (uint256 outputAmount) {
        _permit(orderPayload.order.inputToken, permitPayload);
        return portal(orderPayload);
    }

    /// This function uses Portals signed orders to facilitate gasless portals. It is intended
    /// to be called by a broadcaster (i.e. msg.sender != order.sender).
    /// @param signedOrderPayload The signed order payload containing the details of the signed order
    /// @return outputAmount The quantity of outputToken received after validation of the order
    function portalWithSignature(
        IPortalsRouter.SignedOrderPayload calldata signedOrderPayload
    ) public pausable returns (uint256 outputAmount) {
        _verify(signedOrderPayload);
        return _execute(
            signedOrderPayload.signedOrder.sender,
            signedOrderPayload.signedOrder.order,
            signedOrderPayload.calls,
            _transferFromSender(
                signedOrderPayload.signedOrder.sender,
                signedOrderPayload.signedOrder.order.inputToken,
                signedOrderPayload.signedOrder.order.inputAmount
            )
        );
    }

    /// @notice This function calls permit prior to the portalWithSignature function for gasless approvals,
    /// in addition to gassless Portals. It is intended to be called by a broadcaster (i.e. msg.sender != order.sender).
    /// @param signedOrderPayload The signed order payload containing the details of the signed order
    /// @param permitPayload The permit payload struct containing the details of the permit
    /// @return outputAmount The quantity of outputToken received after validation of the order
    function portalWithSignatureAndPermit(
        IPortalsRouter.SignedOrderPayload calldata signedOrderPayload,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external pausable returns (uint256 outputAmount) {
        _permit(
            signedOrderPayload.signedOrder.order.inputToken,
            permitPayload
        );

        return portalWithSignature(signedOrderPayload);
    }

    /// @notice This function executes calls to transform a sell token into a buy token.
    /// The outputAmount of the outputToken specified in the order is validated against the minOutputAmount following the
    /// aggregate call of Portals Multicall.
    /// @param sender The sender(signer) of the order
    /// @param order The order struct containing the details of the trade
    /// @param calls The array of calls to be executed by the Portals Multicall
    /// @param value The value of native tokens to be sent to the Portals Multicall
    /// @return outputAmount The quantity of outputToken received after validation of the order
    function _execute(
        address sender,
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls,
        uint256 value
    ) private returns (uint256 outputAmount) {
        outputAmount = _getBalance(order.recipient, order.outputToken);

        Portals_Multicall.aggregate{ value: value }(calls);

        outputAmount = _getBalance(order.recipient, order.outputToken)
            - outputAmount;

        if (outputAmount < order.minOutputAmount) {
            revert InsufficientBuy(
                outputAmount, order.minOutputAmount
            );
        }

        emit Portal(
            order.inputToken,
            order.inputAmount,
            order.outputToken,
            outputAmount,
            order.feeToken,
            order.fee,
            sender,
            msg.sender,
            order.recipient,
            order.partner
            );
    }
}

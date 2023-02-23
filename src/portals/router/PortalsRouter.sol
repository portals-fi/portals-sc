/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract routes ERC20 and native tokens to the Portals Multicall contract to
/// transform a sell token into a  minimum quantity of a buy token.

/// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IPortalsRouter } from "./interface/IPortalsRouter.sol";
import { IPortalsMulticall } from
    "../multicall/interface/IPortalsMulticall.sol";
import { RouterBase } from "./RouterBase.sol";

contract PortalsRouter is RouterBase {
    constructor(
        address _admin,
        uint256 _baseFee,
        address _collector,
        address _multicall
    ) RouterBase(_admin, _baseFee, _collector, _multicall) { }

    function portal(
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls
    ) external payable pausable returns (uint256 buyAmount) {
        return _execute(
            msg.sender,
            order,
            calls,
            _transferFromSender(
                msg.sender,
                order.sellToken,
                order.sellAmount,
                order.fee
            )
        );
    }

    function portalWithPermit(
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external payable pausable returns (uint256 buyAmount) {
        _permit(order.sellToken, permitPayload);
        return _execute(
            msg.sender,
            order,
            calls,
            _transferFromSender(
                msg.sender,
                order.sellToken,
                order.sellAmount,
                order.fee
            )
        );
    }

    function portalWithSignature(
        IPortalsRouter.SignedOrder calldata signedOrder,
        bytes calldata signature,
        IPortalsMulticall.Call[] calldata calls
    ) external payable pausable returns (uint256 buyAmount) {
        _verify(signedOrder, signature);
        return _execute(
            signedOrder.sender,
            signedOrder.order,
            calls,
            _transferFromSender(
                signedOrder.sender,
                signedOrder.order.sellToken,
                signedOrder.order.sellAmount,
                signedOrder.order.fee
            )
        );
    }

    function portalWithSignatureAndPermit(
        IPortalsRouter.SignedOrder calldata signedOrder,
        bytes calldata signature,
        IPortalsMulticall.Call[] calldata calls,
        IPortalsRouter.PermitPayload calldata permitPayload
    ) external payable pausable returns (uint256 buyAmount) {
        _verify(signedOrder, signature);
        _permit(signedOrder.order.sellToken, permitPayload);
        return _execute(
            signedOrder.sender,
            signedOrder.order,
            calls,
            _transferFromSender(
                signedOrder.sender,
                signedOrder.order.sellToken,
                signedOrder.order.sellAmount,
                signedOrder.order.fee
            )
        );
    }

    function _execute(
        address sender,
        IPortalsRouter.Order calldata order,
        IPortalsMulticall.Call[] calldata calls,
        uint256 value
    ) private returns (uint256 buyAmount) {
        buyAmount = _getBalance(order.recipient, order.buyToken);

        PORTALS_MULTICALL.aggregate{ value: value }(calls);

        buyAmount =
            _getBalance(order.recipient, order.buyToken) - buyAmount;

        if (buyAmount < order.minBuyAmount) {
            revert InsufficientBuy(buyAmount, order.minBuyAmount);
        }

        emit Portal(
            order.sellToken,
            order.sellAmount,
            order.buyToken,
            buyAmount,
            order.fee,
            sender,
            order.recipient,
            order.partner
            );
    }
}

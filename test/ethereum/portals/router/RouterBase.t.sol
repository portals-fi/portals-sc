/// SPDX-License-Identifier: GPL-3.0

/// Copyright (C) 2023 Portals.fi

/// @author Portals.fi
/// @notice This contract tests RouterBase functions

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { PortalsRouter } from
    "../../../../src/portals/router/PortalsRouter.sol";
import { PortalsMulticall } from
    "../../../../src/portals/multicall/PortalsMulticall.sol";
import { IPortalsRouter } from
    "../../../../src/portals/router/interface/IPortalsRouter.sol";

import { IPortalsMulticall } from
    "../../../../src/portals/multicall/interface/IPortalsMulticall.sol";

import { Quote } from "../../../utils/Quote/Quote.sol";
import { IQuote } from "../../../utils/Quote/interface/IQuote.sol";
import { SigUtils } from "../../../utils/SigUtils.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract RouterBaseTest is Test {
    uint256 mainnetFork =
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

    uint256 internal ownerPrivateKey = 0xDAD;
    uint256 internal userPrivateKey = 0xB0B;
    uint256 internal collectorPivateKey = 0xA11CE;
    uint256 internal adversaryPivateKey = 0xC0C;
    uint256 internal partnerPivateKey = 0xC0FFEE;
    uint256 internal broadcasterPrivateKey = 0xBABE;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal user = vm.addr(userPrivateKey);
    address internal collector = vm.addr(collectorPivateKey);
    address internal adversary = vm.addr(adversaryPivateKey);
    address internal partner = vm.addr(partnerPivateKey);
    address internal broadcaster = vm.addr(broadcasterPrivateKey);

    uint256 fee = 15;

    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal ETH = address(0);
    address internal StargateUSDC =
        0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56;
    address internal StargateRouter =
        0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    bytes32 internal USDC_DOMAIN_SEPARATOR =
        0x06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335;
    bytes32 internal DAI_DOMAIN_SEPARATOR =
        0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    PortalsMulticall public multicall = new PortalsMulticall();

    PortalsRouter public router = new PortalsRouter(owner, multicall);

    Quote public quote = new Quote();

    function setUp() public {
        startHoax(user);
    }

    function PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate()
        public
    {
        address inputToken = address(0);
        uint256 inputAmount = 5 ether;
        uint256 value = inputAmount;

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 3;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
            inputToken, inputAmount, intermediateToken, "0.03"
        );

        (address target, bytes memory data) = quote.quote(quoteParams);

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            inputToken, target, data, type(uint256).max
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[2] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portal{ value: value }(orderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function PortalInWithPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
        uint32 inputAmount
    ) public {
        address inputToken = USDC;
        vm.assume(inputAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.PermitPayload memory permitPayload =
        createPermitPayload(
            inputToken, true, false, USDC_DOMAIN_SEPARATOR
        );

        IPortalsRouter.OrderPayload memory orderPayload =
        IPortalsRouter.OrderPayload({ order: order, calls: calls });

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.portalWithPermit(orderPayload, permitPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function PortalInWithSignature_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
        uint32 inputAmount
    ) public {
        address inputToken = USDC;
        vm.assume(inputAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        address target;
        bytes memory data;
        if (inputToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                inputToken, inputAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
        createSignedOrderPayload(
            order,
            calls,
            router.DOMAIN_SEPARATOR(),
            user,
            userPrivateKey
        );
        signedOrderPayload.calls = calls;

        ERC20(inputToken).approve(address(router), inputAmount);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignature(signedOrderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function PortalInWithSignatureAndPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
    ) public {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        address target;
        bytes memory data;
        if (inputToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                inputToken, inputAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
        createSignedOrderPayload(
            order,
            calls,
            router.DOMAIN_SEPARATOR(),
            user,
            userPrivateKey
        );
        signedOrderPayload.calls = calls;

        IPortalsRouter.PermitPayload memory permitPayload =
        createPermitPayload(
            inputToken, true, false, USDC_DOMAIN_SEPARATOR
        );

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        changePrank(broadcaster);

        router.portalWithSignatureAndPermit(
            signedOrderPayload, permitPayload, partner
        );

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function testFail_invalidateNextOrder(uint32 inputAmount)
        public
    {
        address inputToken = USDC;
        vm.assume(inputAmount > 1); //uint32 limits USDC to 4.29K

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        address intermediateToken = USDC;

        address outputToken = StargateUSDC;

        uint16 poolId = 1;

        uint256 numCalls = 2;

        IPortalsRouter.Order memory order = IPortalsRouter.Order({
            inputToken: inputToken,
            inputAmount: inputAmount,
            outputToken: outputToken,
            minOutputAmount: 1,
            recipient: user
        });

        address target;
        bytes memory data;
        if (inputToken != intermediateToken) {
            IQuote.QuoteParams memory quoteParams = IQuote.QuoteParams(
                inputToken, inputAmount, intermediateToken, "0.03"
            );

            (target, data) = quote.quote(quoteParams);
        }

        IPortalsMulticall.Call[] memory calls =
            new IPortalsMulticall.Call[](numCalls);

        calls[0] = IPortalsMulticall.Call(
            intermediateToken,
            intermediateToken,
            abi.encodeWithSignature(
                "approve(address,uint256)", StargateRouter, 0
            ),
            1
        );
        calls[1] = IPortalsMulticall.Call(
            intermediateToken,
            StargateRouter,
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,address)",
                poolId,
                0,
                user
            ),
            1
        );

        IPortalsRouter.SignedOrderPayload memory signedOrderPayload =
        createSignedOrderPayload(
            order,
            calls,
            router.DOMAIN_SEPARATOR(),
            user,
            userPrivateKey
        );
        signedOrderPayload.calls = calls;

        ERC20(inputToken).approve(address(router), inputAmount);

        uint256 initialBalance = ERC20(outputToken).balanceOf(user);

        router.invalidateNextOrder();

        changePrank(broadcaster);

        router.portalWithSignature(signedOrderPayload, partner);

        uint256 finalBalance = ERC20(outputToken).balanceOf(user);

        assertTrue(finalBalance > initialBalance);
    }

    function test_Pausable() public {
        changePrank(owner);
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());
    }

    function test_UnPausable() public {
        changePrank(owner);
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());
        router.unpause();
        assertFalse(router.paused());
    }

    function testFail_Pausable_by_Admin_Only() public {
        changePrank(adversary);
        assertTrue(!router.paused());
        router.pause();
    }

    function testFail_UnPausable_by_Admin_Only() public {
        changePrank(owner);
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());
        changePrank(adversary);
        router.unpause();
        assertTrue(router.paused());
    }

    function test_setMulticall() public {
        IPortalsMulticall newMulticall = new PortalsMulticall();
        assertFalse(
            address(router.portalsMulticall())
                == address(newMulticall)
        );
        assertEq(
            address(router.portalsMulticall()), address(multicall)
        );
        changePrank(owner);
        router.setMulticall(newMulticall);
        assertEq(
            address(router.portalsMulticall()), address(newMulticall)
        );
    }

    function testFail_setMulticall_by_Admin_Only() public {
        IPortalsMulticall newMulticall = new PortalsMulticall();
        assertFalse(
            address(router.portalsMulticall())
                == address(newMulticall)
        );
        assertEq(
            address(router.portalsMulticall()), address(multicall)
        );
        router.setMulticall(newMulticall);
    }

    function test_ERC20_recoverToken() public {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        ERC20(inputToken).transfer(address(router), inputAmount);

        assertEq(
            ERC20(inputToken).balanceOf(address(router)), inputAmount
        );

        changePrank(owner);
        uint256 beforeRecovery = ERC20(inputToken).balanceOf(user);
        router.recoverToken(inputToken, inputAmount, user);
        assertEq(
            ERC20(inputToken).balanceOf(user) - beforeRecovery,
            inputAmount
        );
    }

    function testFail_ERC20_recoverToken_by_Admin_Only() public {
        address inputToken = USDC;
        uint256 inputAmount = 5_000_000_000; // 5000 USDC

        deal(address(inputToken), user, inputAmount);
        assertEq(ERC20(inputToken).balanceOf(user), inputAmount);

        ERC20(inputToken).transfer(address(router), inputAmount);

        assertEq(
            ERC20(inputToken).balanceOf(address(router)), inputAmount
        );

        changePrank(adversary);
        router.recoverToken(inputToken, inputAmount, adversary);
    }

    function test_ETH_cant_be_sent_to_router() public {
        uint256 inputAmount = 5 ether;

        (bool sent,) = address(router).call{ value: inputAmount }("");

        assertEq(sent, false);
    }

    function testFail_Portal_Reverts_When_Paused() public {
        changePrank(owner);
        assertTrue(!router.paused());
        router.pause();
        assertTrue(router.paused());
        PortalIn_Stargate_SUSDC_From_ETH_With_USDC_Intermediate();
        PortalInWithPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
            4_000_000_000
        );
        PortalInWithSignature_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
            4_000_000_000
        );
        PortalInWithSignatureAndPermit_Stargate_SUSDC_From_USDC_With_USDC_Intermediate(
        );
    }

    function createPermitPayload(
        address inputToken,
        bool splitSignature,
        bool daiPermit,
        bytes32 domainSeparator
    )
        public
        returns (IPortalsRouter.PermitPayload memory permitPayload)
    {
        SigUtils sigUtils = new SigUtils(domainSeparator);

        bytes32 digest;
        if (daiPermit) {
            SigUtils.DaiPermit memory _daiPermit = SigUtils.DaiPermit({
                holder: user,
                spender: address(router),
                nonce: ERC20(inputToken).nonces(user),
                expiry: type(uint256).max,
                allowed: true
            });
            digest = sigUtils.getDaiPermitTypedDataHash(_daiPermit);
        } else {
            SigUtils.Permit memory permit = SigUtils.Permit({
                owner: user,
                spender: address(router),
                value: type(uint256).max,
                nonce: ERC20(inputToken).nonces(user),
                deadline: type(uint256).max
            });

            digest = sigUtils.getPermitTypedDataHash(permit);
        }
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(userPrivateKey, digest);

        permitPayload = IPortalsRouter.PermitPayload({
            amount: type(uint256).max,
            deadline: type(uint256).max,
            signature: abi.encodePacked(r, s, v),
            splitSignature: splitSignature,
            daiPermit: daiPermit
        });
    }

    function createSignedOrderPayload(
        IPortalsRouter.Order memory order,
        IPortalsMulticall.Call[] memory calls,
        bytes32 domainSeparator,
        address sender,
        uint256 senderPrivateKey
    )
        public
        returns (
            IPortalsRouter.SignedOrderPayload memory signedOrderPayload
        )
    {
        SigUtils sigUtils = new SigUtils(domainSeparator);

        IPortalsRouter.SignedOrder memory signedOrder = IPortalsRouter
            .SignedOrder({
            order: order,
            routeHash: keccak256(abi.encode(calls)),
            sender: sender,
            deadline: type(uint32).max,
            nonce: router.nonces(sender)
        });

        bytes32 digest =
            sigUtils.getSignedOrderTypedDataHash(signedOrder);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(senderPrivateKey, digest);

        signedOrderPayload = IPortalsRouter.SignedOrderPayload({
            signedOrder: signedOrder,
            signature: abi.encodePacked(r, s, v),
            calls: calls
        });
    }
}

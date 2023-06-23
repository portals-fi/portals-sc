# Portals Router and Accessory Contracts

## Summary
Portals.fi uses an RFQ system where a caller requests a quote from the Portals API with the input and output tokens, the input amount and the sender/recipient. Once a request is received, the "Warpdrive" algorithm is used to determine the best route (highest USD output + least gas consumption) to complete the transformation. In addition, as the route is being generated, all of the appropriate calls required (i.e. the steps) are appended to a `Call` array for use in the [Portals Multicall](https://github.com/portals-fi/portals-sc/blob/main/src/portals/multicall/PortalsMulticall.sol) contract. Finally, the API returns an unsigned "Order" transaction or EIP-712 "Signed Order" representing the caller's intent to transform the input token into the output token, which can be signed and broadcasted by a user's wallet (or by the Galaxy Broadcasting System for gas-abstracted swaps).

## Architecture
### Flow
The [Portals Router](https://github.com/portals-fi/portals-sc/blob/main/src/portals/router/PortalsRouter.sol) is the entry point and approval target for this system. The Router inherits its base functionality from the [Router Base](https://github.com/portals-fi/portals-sc/blob/main/src/portals/router/RouterBase.sol) contract which allows the `PortalsRouter` to check balances, perform transfers, verify signed orders and permit messages, pause or unpause the contract, and update the address of the `PortalsMulticall` contract.

The Router facilitates two types of orders as described in the [summary](#summary): Orders and Signed Orders. 

To submit an Order, a caller uses the `portal` or `portalWithPermit` function, which transfers funds from msg.sender to the `PortalsMulticall` via `_transferFromSender` in `RouterBase`. In cases where allowance is granted to the `PortalsRouter` via a permit, the permit payload is executed first prior to transferring funds to the `PortalsMulticall` contract.

To submit a Signed Order, the `portalWithSignature` or `portalWithSignatureAndPermit` function can be used. These functions require a signed EIP-712 message containing the details of the Order to be submitted. Subsequently, the Signed Order is verified by the `_verify` function in `PortalBase` using OpenZeppelin's [SignatureChecker](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6ddacdbde856e203e222e3adc461dccce0c2930b/contracts/utils/cryptography/SignatureChecker.sol) library prior to transferring funds to the `PortalsMulticall` contract as described above.

Once the funds have been successfully transferred to the `PortalsMulticall` contract, the `_execute` function in `PortalsRouter` is called to begin excution of the `Call` array which contains the encoded calls required to transform the input token into the output token. The `PortalsMulticall` contract performs the transformation using a cascading balances mechanism where the output of the previous step is used as the input for the next step. Simple pre- and post-call hooks in `PortalsRouter` check the recipient's balance before and after the transformation to ensure that at least the minimum output amount specified in the order is recieved. If the post-call hook succeeds, the transction is successfully completed, otherwise the transaction is reverted.

### Dependencies
#### Solmate
* [ERC20](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
* [SafeTransferLib](https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
* [ReentrancyGuard](https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
* [Owned](https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
#### OpenZeppelin
* [SignatureChecker](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6ddacdbde856e203e222e3adc461dccce0c2930b/contracts/utils/cryptography/SignatureChecker.sol)
* [Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6ddacdbde856e203e222e3adc461dccce0c2930b/contracts/security/Pausable.sol)



## Testing and Development
### Generate an ABI
`forge inspect src/portals/router/PortalsMulticall.sol:PortalsMulticall abi > ./abi/PortalsMulticall.sol/PortalsMulticall.json`
### Tests
#### Load .env vars for the first time (if necessary) 
`source .env`
#### Run a specific test
`forge test --match-contract PortalsRouterTest --ffi -vvv --etherscan-api-key 9UD3... --gas-report`
#### Run all tests
`forge test`
### Deployments
#### Simulate Deployment:
`forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL`
#### Broadcast Deployment:
`forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL --broadcast`

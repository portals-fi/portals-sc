# Portals Router and Accessory Contracts

## Summary
Portals.fi uses an RFQ system where a caller requests a quote from the Portals API with the input and output tokens, the input amount and the sender/recipient. Once a request is received, the "Warpdrive" algorithm is used to determine the best route (highest USD output + least gas consumption) to complete the transformation. In addition, as the route is being generated, all of the appropriate calls required (i.e. the steps) are appended to an array for use in the [Portals Multicall](https://github.com/portals-fi/portals-sc/blob/main/src/portals/multicall/PortalsMulticall.sol) contract. Finally, the API returns an unsigned "Order" transaction or EIP-712 "Signed Order" that represents the transformation from the input to the output token, which can be signed and broadcasted by a user's wallet (or by the Galaxy Broadcasting System for gas-abstracted swaps)

## Architecture
The [Portals Router](https://github.com/portals-fi/portals-sc/blob/main/src/portals/router/PortalsRouter.sol) is the entry point and approval target for this system. The Router inherits its base functionality from the [Router Base](https://github.com/portals-fi/portals-sc/blob/main/src/portals/router/RouterBase.sol) contract which allows the `PortalsRouter` to check balances, perform transfers, verify signed orders and permit messages, pause or unpause the contract, and update the address of the `PortalsMulticall` contract.

The Router facilitates two types of orders as described in the [summary](#summary): Orders and Signed Orders. 

To submit an Order, a caller uses the `portal` or `portalWithPermit` function, which transfers funds from msg.sender to the `PortalsMulticall` contract (where input token is an ERC20) via `_transferFromSender` in `RouterBase`

## Testing and Development
### Generate an ABI
`forge inspect src/portals/router/PortalsMulticall.sol:PortalsMulticall abi > ./abi/PortalsMulticall.sol/PortalsMulticall.json`

### Tests
#### Load .env vars for the first time (if necessary) 
`source .env`
#### Run a specific test
`forge test --match-contract PortalsRouterTest --ffi -vvv --etherscan-api-key 9UD3... --gas-report`
### Deployments
#### Simulate Deployment:
`forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL`
#### Broadcast Deployment:
`forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL --broadcast`

# portals-sc
Portals Foundry Smart Contract Repo

## Useful Commands
### Generate an ABI
`forge inspect src/portals/router/PortalsMulticall.sol:PortalsMulticall abi > ./abi/PortalsMulticall.sol/PortalsMulticall.json`

## Tests
### Load .env vars for the first time (if necessary) 
`source .env`
### Run a specific test
`forge test --match-contract PortalsRouterTest --ffi -vvv --etherscan-api-key 9UD3... --gas-report`
## Deployments
### Simulate Deployment:
`forge forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL`
### Broadcast Deployment:
`forge script script/polygon/portals/router/PortalsRouter.s.sol:PortalsRouterDeployer -vvvv --rpc-url $POLYGON_RPC_URL --broadcast`

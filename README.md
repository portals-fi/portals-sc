# portals-sc
Portals Foundry Smart Contract Repo

## Useful Commands
### Generate an ABI
`forge inspect src/portals/router/PortalsMulticall.sol:PortalsMulticall abi > ./abi/PortalsMulticall.sol/PortalsMulticall.json`

### Run a specific test
`forge test --match-contract PortalsRouterTest --ffi -vvv --etherscan-api-key 9UD3... --gas-report`

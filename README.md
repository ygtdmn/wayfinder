# Multiplex
A Manifold Creator Extension for minting tokens with multiple media pointers. The idea was first explored in the art project [Off-Chain Art](https://x.com/YigitDuman/status/1957514000306246110) by [Yigit Duman](https://x.com/YigitDuman).

## Work In Progress
The project is currently WIP. The contract is deployed on Sepolia testnet and the frontend is a vibecoded frontend to interact with the contract.

## Deployments
### Sepolia
**Multiplex:** 0x062EE7ceC8C01133bF5c68bD5C7d515fE3eC39e4
**MultiplexManifoldExtension:** 0xf689d41DeA48B94ea9cE9d6e88E01fb9fD97F46f

## TODO
### Contract
- Write proper tests for the contract
- Reduce contract size to be able to build without --via-ir flag
- Write proper documentation

### Frontend
- CRITICAL: Update to work with new MultiplexManifoldExtension
- Remove hacky type declarations and useMemo usages, and improve overall TypeScript practices
- Write proper documentation
- If extension is registered, fix asking to register again
- Properly implement collector zone
- In collector zone, automatically discover owned NFTs created with Multiplex
- Properly implement update artwork section
- Test both ERC721 and ERC1155 contracts
- Implement meta tags and favicon
- Remove vibecoded sloppy stuff

Feel free to open issues or send pull requests. Also, if you're interested in being a maintainer please contact me on X or Discord (username: ygtdmn).
// ERC1155 Creator Core minimal ABI (const-asserted for Wagmi/Viem type inference)
export const ierc1155CreatorCoreAbi = [
  {
    type: "function",
    name: "supportsInterface",
    inputs: [{ name: "interfaceId", type: "bytes4", internalType: "bytes4" }],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "registerExtension",
    inputs: [
      { name: "extension", type: "address", internalType: "address" },
      { name: "baseURI", type: "string", internalType: "string" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;



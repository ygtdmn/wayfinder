// Complete Multiplex ABI with as const for proper type inference
export const multiplexAbi = 
[
  {
    "type": "function",
    "name": "addArtistArtworkUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "uris",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addArtistThumbnailUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "uris",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addCollectorArtworkUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "uris",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getArtistArtworkUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getArtistThumbnailUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCollectorArtworkUris",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "string[]",
        "internalType": "string[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getHtmlTemplate",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lockMetadata",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "lockThumbnail",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "mintERC1155",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "params",
        "type": "tuple",
        "internalType": "struct Multiplex.MintERC1155Params",
        "components": [
          {
            "name": "baseParams",
            "type": "tuple",
            "internalType": "struct Multiplex.MintParams",
            "components": [
              {
                "name": "metadata",
                "type": "string",
                "internalType": "string"
              },
              {
                "name": "onChainThumbnail",
                "type": "tuple",
                "internalType": "struct Multiplex.File",
                "components": [
                  {
                    "name": "mimeType",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "chunks",
                    "type": "address[]",
                    "internalType": "address[]"
                  },
                  {
                    "name": "length",
                    "type": "uint256",
                    "internalType": "uint256"
                  },
                  {
                    "name": "zipped",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "deflated",
                    "type": "bool",
                    "internalType": "bool"
                  }
                ]
              },
              {
                "name": "initialDisplayMode",
                "type": "uint8",
                "internalType": "enum Multiplex.DisplayMode"
              },
              {
                "name": "immutableProperties",
                "type": "tuple",
                "internalType": "struct Multiplex.ImmutableProperties",
                "components": [
                  {
                    "name": "imageHash",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "imageMimeType",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "isAnimationUri",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "useOffchainThumbnail",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorAddArtwork",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorSelectArtistArtwork",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorSelectArtistThumbnail",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorToggleDisplayMode",
                    "type": "bool",
                    "internalType": "bool"
                  }
                ]
              },
              {
                "name": "seedArtistArtworkUris",
                "type": "string[]",
                "internalType": "string[]"
              },
              {
                "name": "seedArtistThumbnailUris",
                "type": "string[]",
                "internalType": "string[]"
              }
            ]
          },
          {
            "name": "recipients",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "quantities",
            "type": "uint256[]",
            "internalType": "uint256[]"
          }
        ]
      },
      {
        "name": "thumbnailChunks",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "mintERC721",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "params",
        "type": "tuple",
        "internalType": "struct Multiplex.MintERC721Params",
        "components": [
          {
            "name": "baseParams",
            "type": "tuple",
            "internalType": "struct Multiplex.MintParams",
            "components": [
              {
                "name": "metadata",
                "type": "string",
                "internalType": "string"
              },
              {
                "name": "onChainThumbnail",
                "type": "tuple",
                "internalType": "struct Multiplex.File",
                "components": [
                  {
                    "name": "mimeType",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "chunks",
                    "type": "address[]",
                    "internalType": "address[]"
                  },
                  {
                    "name": "length",
                    "type": "uint256",
                    "internalType": "uint256"
                  },
                  {
                    "name": "zipped",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "deflated",
                    "type": "bool",
                    "internalType": "bool"
                  }
                ]
              },
              {
                "name": "initialDisplayMode",
                "type": "uint8",
                "internalType": "enum Multiplex.DisplayMode"
              },
              {
                "name": "immutableProperties",
                "type": "tuple",
                "internalType": "struct Multiplex.ImmutableProperties",
                "components": [
                  {
                    "name": "imageHash",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "imageMimeType",
                    "type": "string",
                    "internalType": "string"
                  },
                  {
                    "name": "isAnimationUri",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "useOffchainThumbnail",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorAddArtwork",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorSelectArtistArtwork",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorSelectArtistThumbnail",
                    "type": "bool",
                    "internalType": "bool"
                  },
                  {
                    "name": "allowCollectorToggleDisplayMode",
                    "type": "bool",
                    "internalType": "bool"
                  }
                ]
              },
              {
                "name": "seedArtistArtworkUris",
                "type": "string[]",
                "internalType": "string[]"
              },
              {
                "name": "seedArtistThumbnailUris",
                "type": "string[]",
                "internalType": "string[]"
              }
            ]
          },
          {
            "name": "recipients",
            "type": "address[]",
            "internalType": "address[]"
          }
        ]
      },
      {
        "name": "thumbnailChunks",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "removeArtistArtworkUri",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "removeArtistThumbnailUri",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "tokenData",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "metadata",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "onChainThumbnail",
        "type": "tuple",
        "internalType": "struct Multiplex.File",
        "components": [
          {
            "name": "mimeType",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "chunks",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "length",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "zipped",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "deflated",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      },
      {
        "name": "displayMode",
        "type": "uint8",
        "internalType": "enum Multiplex.DisplayMode"
      },
      {
        "name": "immutableProperties",
        "type": "tuple",
        "internalType": "struct Multiplex.ImmutableProperties",
        "components": [
          {
            "name": "imageHash",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "imageMimeType",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "isAnimationUri",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "useOffchainThumbnail",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "allowCollectorAddArtwork",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "allowCollectorSelectArtistArtwork",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "allowCollectorSelectArtistThumbnail",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "allowCollectorToggleDisplayMode",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      },
      {
        "name": "offchain",
        "type": "tuple",
        "internalType": "struct Multiplex.OffChainData",
        "components": [
          {
            "name": "artistArtworkUris",
            "type": "string[]",
            "internalType": "string[]"
          },
          {
            "name": "collectorArtworkUris",
            "type": "string[]",
            "internalType": "string[]"
          },
          {
            "name": "artistThumbnailUris",
            "type": "string[]",
            "internalType": "string[]"
          }
        ]
      },
      {
        "name": "selection",
        "type": "tuple",
        "internalType": "struct Multiplex.Selection",
        "components": [
          {
            "name": "selectedArtistArtworkIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "selectedArtistThumbnailIndex",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "metadataLocked",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "thumbnailLocked",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "updateToken",
    "inputs": [
      {
        "name": "creatorContractAddress",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "params",
        "type": "tuple",
        "internalType": "struct Multiplex.UpdateParams",
        "components": [
          {
            "name": "metadata",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "updateMetadata",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "thumbnailChunks",
            "type": "bytes[]",
            "internalType": "bytes[]"
          },
          {
            "name": "thumbnailOptions",
            "type": "tuple",
            "internalType": "struct Multiplex.File",
            "components": [
              {
                "name": "mimeType",
                "type": "string",
                "internalType": "string"
              },
              {
                "name": "chunks",
                "type": "address[]",
                "internalType": "address[]"
              },
              {
                "name": "length",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "zipped",
                "type": "bool",
                "internalType": "bool"
              },
              {
                "name": "deflated",
                "type": "bool",
                "internalType": "bool"
              }
            ]
          },
          {
            "name": "updateThumbnail",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "displayMode",
            "type": "uint8",
            "internalType": "enum Multiplex.DisplayMode"
          },
          {
            "name": "updateDisplayMode",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "selectedArtistArtworkIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "updateSelectedArtistArtwork",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "selectedArtistThumbnailIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "updateSelectedArtistThumbnail",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const;

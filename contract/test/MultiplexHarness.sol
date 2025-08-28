// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Multiplex } from "src/Multiplex.sol";

contract MultiplexHarness is Multiplex {
    constructor() Multiplex("<html>{{FILE_URIS}}</html>", false) { }

    function isContractAdminPublic(address contractAddress) external view returns (bool) {
        return _isContractAdmin(contractAddress);
    }

    function isTokenOwnerPublic(address contractAddress, uint256 tokenId) external view returns (bool) {
        return _isTokenOwner(contractAddress, tokenId);
    }

    function resolveThumbnailUriPublic(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string memory)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        return _resolveThumbnailUri(token);
    }

    function combinedArtworkUrisPublic(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string memory)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        return _combinedArtworkUris(token);
    }

    function loadOnChainThumbnailPublic(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (bytes memory)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        return _loadOnChainThumbnail(token.thumbnail.onChain);
    }

    function encodeDataUriPublic(
        string memory mimeType,
        bytes memory data,
        bool utf8Charset
    )
        external
        pure
        returns (string memory)
    {
        return _encodeDataUri(mimeType, data, utf8Charset);
    }

    function appendJsonFieldPublic(string memory json, string memory field) external pure returns (string memory) {
        return _appendJsonField(json, field);
    }
}

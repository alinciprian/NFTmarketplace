//SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract singleNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => bool) _tokenURIExists;
    address marketplaceAddress;

    constructor(address marketplace) ERC721("SingleNFT Asset", "LNFT") {
        marketplaceAddress = marketplace;
    }

    function createItem(string memory tokenURI) public returns (uint256) {
        require(
            !_tokenURIExists[tokenURI],
            "ERC721Metadata: URI token should be unique !"
        );
        _tokenURIExists[tokenURI] = true;
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(marketplaceAddress, true);
        return newItemId;
    }

    function setMarketplaceAddress (address marketplace) public onlyOwner {
        marketplaceAddress = marketplace;
    }
}

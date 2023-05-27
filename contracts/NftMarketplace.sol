//SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;

import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

error PriceNotMet(address nftContract, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftContract, uint256 tokenId);
error NotListed(address nftContract, uint256 tokenId);
error AlreadyListed(address nftContract, uint256 tokenId);
error NoUnclaimedFunds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract NftMarketplace is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _itemsId;

    uint256 marketplaceFee;
    address payable marketplaceOwner;

    struct Sell {
        address payable owner;
        address payable creator;
        uint256 royalties;
        uint256 price;
    }

    struct Auction {
        address payable owner;
        address payable creator;
        uint256 price;
        uint256 deadline;
        uint256 duration;
        address latestBidder;
        uint256 latestBid;
        uint256 royalties;
    }

    event newAuction(address nftContract, uint256 tokenId, uint256 deadline);
    event ItemOnSale(
        address seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address creator,
        uint256 royalties
    );

    mapping(address => uint256) public unclaimedFunds;
    mapping(address => mapping(uint256 => Sell)) public ERC721Sells;
    mapping(address => mapping(uint256 => Auction)) public ERC721Auctions;

    modifier notListed(address nftContract, uint256 tokenId) {
        Sell memory sell = ERC721Sells[nftContract][tokenId];
        if (sell.price > 0) {
            revert AlreadyListed(nftContract, tokenId);
        }
        _;
    }

    modifier isListed(address nftContract, uint256 tokenId) {
        Sell memory sell = ERC721Sells[nftContract][tokenId];
        if (sell.price <= 0) {
            revert NotListed(nftContract, tokenId);
        }
        _;
    }

    modifier isOwner(
        address nftContract,
        uint256 tokenId,
        address spender
    ) {
        ERC721 nft = ERC721(nftContract);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor() {
        marketplaceOwner = payable(msg.sender);
    }

    function setMarketFee(uint256 price) public onlyOwner {
        marketplaceFee = price;
    }

    /** claimFunds allows user to redeem the funds stored in the marketplace contract. */
    function claimFunds() external nonReentrant {
        uint256 userFunds = unclaimedFunds[msg.sender];
        if (unclaimedFunds[msg.sender] <= 0) {
            revert NoUnclaimedFunds();
        }
        unclaimedFunds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: userFunds}("");
        require(success, "Transfer Failed");
    }

    /** setItemOnSale Must be called only by owner, must not be previously listed
    Listing price must be above 0, must be approved. At the end, emits event*/

    function setItemOnSale(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address creator,
        uint256 royalties
    )
        external
        
        isOwner(nftContract, tokenId, msg.sender)
        nonReentrant
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftContract);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }

        _safeTransferFrom(tokenId, msg.sender, address(this), nftContract);
    }

    function _safeTransferFrom(
        uint256 _tokenId,
        address _from,
        address _to,
        address _nftContract
    ) internal {
        IERC721(_nftContract).safeTransferFrom(_from, _to, _tokenId);
    }
}

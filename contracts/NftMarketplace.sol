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
error CurrentlyInAuction(address nftContract, uint256 tokenId);
error CurrentlyNotInAuction(address nftContract, uint256 tokenId);
error NoUnclaimedFunds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();
error InvalidArguments();
error NewBidMustBeHigher();

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
    event auctionCancelled(address nftContract, uint256 tokenId);
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

    modifier notAuctioned(address nftContract, uint256 tokenId) {
        Auction memory auction = ERC721Auctions[nftContract][tokenId];
        if (auction.price > 0) {
            revert CurrentlyInAuction(nftContract, tokenId);
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

    modifier isAuctioned(address nftContract, uint256 tokenId) {
        Auction memory auction = ERC721Auctions[nftContract][tokenId];
        if (auction.price <= 0) {
            revert CurrentlyNotInAuction(nftContract, tokenId);
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

    /** claimFunds allows user to redeem the funds stored in the marketplace contract.--------- */
    function claimFunds() external nonReentrant {
        uint256 userFunds = unclaimedFunds[msg.sender];
        if (unclaimedFunds[msg.sender] <= 0) {
            revert NoUnclaimedFunds();
        }
        unclaimedFunds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: userFunds}("");
        require(success, "Transfer Failed");
    }

    // START SELLING

    /** setItemOnSale Must be called only by owner, must not be previously listed
    Listing price must be above 0, must be approved. At the end, emits event*/

    function setItemOnSale(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address creator,
        uint256 royalties
    ) external isOwner(nftContract, tokenId, msg.sender) nonReentrant {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftContract);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }

        _safeTransferFrom(tokenId, msg.sender, address(this), nftContract);
        ERC721Sells[nftContract][tokenId].owner = payable(msg.sender);
        ERC721Sells[nftContract][tokenId].price = price;
        ERC721Sells[nftContract][tokenId].creator = payable(creator);
        ERC721Sells[nftContract][tokenId].royalties = royalties;
        emit ItemOnSale(msg.sender, nftContract, tokenId, price, creator, royalties);
    }

    function cancelSell(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant isOwner(nftContract, tokenId, msg.sender) {
        delete ERC721Sells[nftContract][tokenId];
        _safeTransferFrom(tokenId, address(this), msg.sender, nftContract);
        emit auctionCancelled(nftContract, tokenId);
    }

    function buyItem(
        address nftContract,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftContract, tokenId) {
        Sell memory sell = ERC721Sells[nftContract][tokenId];
        delete ERC721Sells[nftContract][tokenId];
        if (msg.value < sell.price) {
            revert PriceNotMet(nftContract, tokenId, sell.price);
        }

        _safeTransferFrom(tokenId, address(this), msg.sender, nftContract);

        uint256 marketplace_royalties = sell.price.div(100).mul(marketplaceFee);

        uint256 creator_royalties = msg.value.div(100).mul(sell.royalties);

        uint256 owner_royalties = msg.value.sub(creator_royalties).sub(marketplace_royalties);

        (bool success, ) = sell.owner.call{value: owner_royalties}("");
        if (!success) {
            unclaimedFunds[sell.owner] += owner_royalties;
        }

        (bool success1, ) = sell.creator.call{value: creator_royalties}("");
        if (!success1) {
            unclaimedFunds[sell.creator] += creator_royalties;
        }

        (bool success2, ) = marketplaceOwner.call{value: marketplace_royalties}("");
        if (!success2) {
            unclaimedFunds[marketplaceOwner] += marketplace_royalties;
        }
    }

    //STOP SELLING

    //AUCTION START

    /** who sets the creator and only owner can call?? 
    At the start of each function create a pointer to the struct stored in contract rather than reading from contract every time*/

    function setItemOnAuction(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 duration,
        uint256 royalties,
        address creator
    ) external nonReentrant notAuctioned(nftContract, tokenId) notListed(nftContract, tokenId) {
        Auction memory auction = ERC721Auctions[nftContract][tokenId];
        if (price <= 0 && duration <= 0 && duration > 25) {
            revert InvalidArguments();
        }

        _safeTransferFrom((tokenId), msg.sender, address(this), nftContract);

        auction.owner = payable(msg.sender);
        auction.creator = payable(creator);
        auction.price = price;
        auction.duration = duration;
        auction.royalties = royalties;
    }


    /**DEADLINE = 0 ? */
    function placeBid(
        address nftContract,
        uint256 tokenId
    ) external payable nonReentrant isAuctioned(nftContract, tokenId) {
        Auction memory auction = ERC721Auctions[nftContract][tokenId];
        require(auction.owner != msg.sender);
        require(
            auction.deadline == 0 ||
                auction.deadline >= block.timestamp, "Auction not valid"
        );

        if(auction.deadline == 0){
            if(msg.value <= auction.price) {
                revert PriceNotMet(nftContract, tokenId, auction.price);
            }
            uint256 timestamp = block.timestamp + auction.duration * 1 hours;
            auction.deadline = timestamp;

            emit newAuction(nftContract, tokenId, timestamp);
        } else {
            if(msg.value <= auction.latestBid + auction.latestBid.mul(15).div(100)) {
                revert NewBidMustBeHigher();
            }
        }
    }

    //AUCTION END

    function _safeTransferFrom(
        uint256 _tokenId,
        address _from,
        address _to,
        address _nftContract
    ) internal {
        IERC721(_nftContract).safeTransferFrom(_from, _to, _tokenId);
    }
}

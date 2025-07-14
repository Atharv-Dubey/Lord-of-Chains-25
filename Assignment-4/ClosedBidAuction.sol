// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClosedBidAuction is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Bid {
        bytes32 hashedBid;
        address bidder;
    }

    uint256 public auctionEndTime;
    uint256 public constant APPLICATION_FEE = 0.01 ether;
    bool public auctionEnded;
    address public winner;
    uint256 public highestBid;

    mapping(address => Bid) private bids;
    mapping(address => bool) public hasBid;

    event BidPlaced(address indexed bidder, uint256 timestamp);
    event AuctionEnded(address indexed winner, uint256 highestBid, uint256 tokenId);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier onlyBeforeAuctionEnd() {
        require(block.timestamp < auctionEndTime && !auctionEnded, "Auction ended");
        _;
    }

    modifier onlyAfterAuctionEnd() {
        require(block.timestamp >= auctionEndTime || auctionEnded, "Auction active");
        _;
    }

    constructor(uint256 durationInSeconds) ERC721("AuctionNFT", "ANFT") Ownable() {
        auctionEndTime = block.timestamp + durationInSeconds;
    }

    function placeBid(bytes32 hashedBid) public payable onlyBeforeAuctionEnd {
        require(!hasBid[msg.sender], "Already bid");
        require(msg.value == APPLICATION_FEE, "Incorrect fee");

        bids[msg.sender] = Bid(hashedBid, msg.sender);
        hasBid[msg.sender] = true;
        emit BidPlaced(msg.sender, block.timestamp);
    }

    function revealBid(uint256 bidAmount, uint256 nonce) public onlyAfterAuctionEnd {
        require(hasBid[msg.sender], "No bid");
        require(!auctionEnded, "Auction finalized");

        Bid storage bid = bids[msg.sender];
        require(keccak256(abi.encodePacked(bidAmount, nonce, msg.sender)) == bid.hashedBid, "Invalid reveal");

        if (bidAmount > highestBid) {
            highestBid = bidAmount;
            winner = msg.sender;
        }
    }

    function finalizeAuction(string memory tokenURI) public onlyOwner onlyAfterAuctionEnd {
        require(!auctionEnded, "Auction finalized");
        auctionEnded = true;

        if (winner != address(0)) {
            uint256 newTokenId = _tokenIds.current();
            _mint(winner, newTokenId);
            _setTokenURI(newTokenId, tokenURI);
            _tokenIds.increment();
            emit AuctionEnded(winner, highestBid, newTokenId);
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "Withdrawal failed");
            emit FundsWithdrawn(owner(), balance);
        }
    }

    function getAuctionStatus() public view returns (bool isActive, uint256 timeRemaining) {
        isActive = block.timestamp < auctionEndTime && !auctionEnded;
        timeRemaining = isActive ? auctionEndTime - block.timestamp : 0;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
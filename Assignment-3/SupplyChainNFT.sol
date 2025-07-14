// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SupplyChainNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Enum to represent different roles in the supply chain
    enum Role { Seller, Warehouse, Delivery, Buyer }

    // Struct to store product details
    struct Product {
        uint256 tokenId;
        Role currentRole;
        uint256 createdAt;
        uint256 deliveryDeadline;
        bool isTemperatureSensitive;
        uint256 expiryTimestamp;
    }

    // Struct to store transfer log details
    struct TransferLog {
        string fromRole;
        string toRole;
        uint256 timestamp;
        string auditNote;
    }

    // Mappings to store products and their transfer histories
    mapping(uint256 => Product) public products;
    mapping(uint256 => TransferLog[]) public transferLogs;

    // Events for tracking transfers and statuses
    event Transfer(uint256 indexed tokenId, Role newRole, uint256 timestamp);
    event DeliveryStatus(uint256 indexed tokenId, string status, uint256 timestamp);
    event ProductExpired(uint256 indexed tokenId, uint256 currentTimestamp);
    event TransitDelay(uint256 indexed tokenId, Role role, uint256 delaySeconds);

    // Modifier to check if the caller is in the correct role
    modifier onlyRole(Role _role) {
        require(products[_tokenIds.current() - 1].currentRole == _role, "Incorrect role for this action");
        _;
    }

    // Modifier to check if product is expired
    modifier notExpired(uint256 tokenId) {
        require(block.timestamp <= products[tokenId].expiryTimestamp, "Product has expired");
        _;
    }

    // Modifier to check audit note
    modifier validAuditNote(string memory auditNote) {
        require(bytes(auditNote).length > 0, "Audit note cannot be empty");
        _;
    }

    constructor() ERC721("SupplyChainNFT", "SCNFT") Ownable() {}

    // Helper function to get role name as string
    function getRoleName(Role role) internal pure returns (string memory) {
        if (role == Role.Seller) return "Seller Ang Seller";
        if (role == Role.Warehouse) return "Warehouse";
        if (role == Role.Delivery) return "Delivery";
        if (role == Role.Buyer) return "Buyer";
        return "Unknown";
    }

    // Function to mint a new product NFT
    function mintProductNFT(
        string memory tokenURI,
        uint256 deliveryDeadline,
        bool isTemperatureSensitive,
        uint256 expiryTimestamp
    ) public returns (uint256) {
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        products[newTokenId] = Product({
            tokenId: newTokenId,
            currentRole: Role.Seller,
            createdAt: block.timestamp,
            deliveryDeadline: deliveryDeadline,
            isTemperatureSensitive: isTemperatureSensitive,
            expiryTimestamp: expiryTimestamp
        });

        _tokenIds.increment();
        return newTokenId;
    }

    // Function to confirm cold storage for temperature-sensitive products
    function confirmColdStorage(uint256 tokenId) public {
        require(products[tokenId].isTemperatureSensitive, "Product is not temperature sensitive");
        require(products[tokenId].currentRole == Role.Warehouse, "Product must be in Warehouse");
        // Simulate cold storage confirmation (could be extended with additional logic)
    }

    // Function to transfer product to the next role
    function transferToNextRole(uint256 tokenId, string memory auditNote)
        public
        notExpired(tokenId)
        validAuditNote(auditNote)
    {
        Product storage product = products[tokenId];
        string memory fromRole = getRoleName(product.currentRole);

        // Temperature sensitivity check
        if (product.isTemperatureSensitive && product.currentRole == Role.Warehouse) {
            // Assuming confirmColdStorage was called separately
        }

        // Role transition logic
        if (product.currentRole == Role.Seller) {
            product.currentRole = Role.Warehouse;
        } else if (product.currentRole == Role.Warehouse) {
            product.currentRole = Role.Delivery;
        } else if (product.currentRole == Role.Delivery) {
            product.currentRole = Role.Buyer;
            // Check delivery status
            string memory status = block.timestamp <= product.deliveryDeadline ? "OnTime" : "Delayed";
            emit DeliveryStatus(tokenId, status, block.timestamp);
        } else {
            revert("Product already delivered to buyer");
        }

        // Log the transfer
        transferLogs[tokenId].push(
            TransferLog({
                fromRole: fromRole,
                toRole: getRoleName(product.currentRole),
                timestamp: block.timestamp,
                auditNote: auditNote
            })
        );

        emit Transfer(tokenId, product.currentRole, block.timestamp);
    }

    // Function to check if product is expired
    function checkExpiry(uint256 tokenId) public {
        if (block.timestamp > products[tokenId].expiryTimestamp) {
            emit ProductExpired(tokenId, block.timestamp);
            revert("Product has expired");
        }
    }

    // Override functions required by ERC721 and ERC721URIStorage
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
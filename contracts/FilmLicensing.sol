// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AssetLicenseNFT is ERC721, Ownable, ReentrancyGuard {
    struct License {
        address creator;
        uint48 validUntil;
        string assetURI;        // URI to the asset (IPFS or other storage)
        string assetMetadata;   // Additional metadata about the asset
        bool isActive;          // To enable/disable licenses
    }

    struct Creator {
        bool isRegistered;
        uint256 totalAssets;
        uint256[] tokenIds;     // Array of token IDs owned by this creator
    }

    // License data by token ID
    mapping(uint256 => License) public licenses;
    
    // Creator data by address
    mapping(address => Creator) public creators;
    
    // Asset URI to token ID mapping (to prevent duplicates)
    mapping(string => uint256) private _assetToToken;
    
    // License fee configuration
    uint256 public baseLicenseFee;
    bool public feesEnabled;
    
    uint256 private _nextTokenId = 1;
    
    event LicenseIssued(uint256 indexed tokenId, address indexed creator, string assetURI);
    event LicenseRenewed(uint256 indexed tokenId, uint48 newValidUntil);
    event LicenseDeactivated(uint256 indexed tokenId);
    event LicenseReactivated(uint256 indexed tokenId);
    event CreatorRegistered(address indexed creator);
    event CreatorRevoked(address indexed creator);
    event AssetUploaded(uint256 indexed tokenId, address indexed creator, string assetURI);
    event FeeUpdated(uint256 newFee);
    event FeesToggled(bool enabled);

    constructor(uint256 initialFee) ERC721("AssetLicense", "ALNS") Ownable(msg.sender) {
        baseLicenseFee = initialFee;
        feesEnabled = true;
    }

    // Registration functions
    function registerCreator(address creator) external onlyOwner {
        require(creator != address(0), "Invalid creator address");
        require(!creators[creator].isRegistered, "Creator already registered");
        
        creators[creator].isRegistered = true;
        emit CreatorRegistered(creator);
    }

    function revokeCreator(address creator) external onlyOwner {
        require(creators[creator].isRegistered, "Creator not registered");
        creators[creator].isRegistered = false;
        emit CreatorRevoked(creator);
    }

    // Self-registration for creators
    function registerSelf() external payable {
        require(!creators[msg.sender].isRegistered, "Already registered");
        
        if (feesEnabled) {
            require(msg.value >= baseLicenseFee, "Insufficient registration fee");
        }
        
        creators[msg.sender].isRegistered = true;
        emit CreatorRegistered(msg.sender);
        
        // Return excess funds if any
        if (msg.value > baseLicenseFee) {
            payable(msg.sender).transfer(msg.value - baseLicenseFee);
        }
    }

    // Asset upload and automatic licensing
    function uploadAsset(
        string calldata assetURI, 
        string calldata assetMetadata, 
        uint48 validityPeriod
    ) 
        external 
        payable 
        nonReentrant 
        returns (uint256) 
    {
        require(creators[msg.sender].isRegistered, "Not a registered creator");
        require(bytes(assetURI).length > 0, "Asset URI cannot be empty");
        require(_assetToToken[assetURI] == 0, "Asset already registered");
        
        // Check if fees need to be paid
        if (feesEnabled) {
            require(msg.value >= baseLicenseFee, "Insufficient license fee");
        }
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        
        // Store license information
        licenses[tokenId] = License({
            creator: msg.sender,
            validUntil: uint48(block.timestamp) + validityPeriod,
            assetURI: assetURI,
            assetMetadata: assetMetadata,
            isActive: true
        });
        
        // Update creator's asset records
        creators[msg.sender].totalAssets++;
        creators[msg.sender].tokenIds.push(tokenId);
        
        // Map asset URI to token ID
        _assetToToken[assetURI] = tokenId;
        
        emit AssetUploaded(tokenId, msg.sender, assetURI);
        emit LicenseIssued(tokenId, msg.sender, assetURI);
        
        // Return excess funds if any
        if (msg.value > baseLicenseFee) {
            payable(msg.sender).transfer(msg.value - baseLicenseFee);
        }
        
        return tokenId;
    }

    // Admin can issue license for a creator (for edge cases)
    function issueLicense(
        address creator, 
        string calldata assetURI,
        string calldata assetMetadata,
        uint48 validityPeriod
    ) 
        external 
        onlyOwner 
        returns (uint256) 
    {
        require(creators[creator].isRegistered, "Not a registered creator");
        require(bytes(assetURI).length > 0, "Asset URI cannot be empty");
        require(_assetToToken[assetURI] == 0, "Asset already registered");

        uint256 tokenId = _nextTokenId++;
        _safeMint(creator, tokenId);
        
        licenses[tokenId] = License({
            creator: creator,
            validUntil: uint48(block.timestamp) + validityPeriod,
            assetURI: assetURI,
            assetMetadata: assetMetadata,
            isActive: true
        });
        
        creators[creator].totalAssets++;
        creators[creator].tokenIds.push(tokenId);
        _assetToToken[assetURI] = tokenId;
        
        emit AssetUploaded(tokenId, creator, assetURI);
        emit LicenseIssued(tokenId, creator, assetURI);
        
        return tokenId;
    }

    // License management functions
    function renewLicense(uint256 tokenId, uint48 additionalTime) external payable {
        require(_isAuthorized(msg.sender, tokenId), "Not owner or approved");
        require(licenses[tokenId].isActive, "License is not active");
        
        if (feesEnabled) {
            require(msg.value >= baseLicenseFee, "Insufficient renewal fee");
        }
        
        // Update expiration date
        licenses[tokenId].validUntil += additionalTime;
        
        emit LicenseRenewed(tokenId, licenses[tokenId].validUntil);
        
        // Return excess funds if any
        if (msg.value > baseLicenseFee) {
            payable(msg.sender).transfer(msg.value - baseLicenseFee);
        }
    }
    
    function deactivateLicense(uint256 tokenId) external {
        require(_isAuthorized(msg.sender, tokenId) || msg.sender == owner(), "Not authorized");
        require(licenses[tokenId].isActive, "License already inactive");
        
        licenses[tokenId].isActive = false;
        emit LicenseDeactivated(tokenId);
    }
    
    function reactivateLicense(uint256 tokenId) external onlyOwner {
        require(!licenses[tokenId].isActive, "License already active");
        
        licenses[tokenId].isActive = true;
        emit LicenseReactivated(tokenId);
    }

    // Helper function to check if sender is authorized for token
    function _isAuthorized(address operator, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (operator == owner || 
                isApprovedForAll(owner, operator) || 
                getApproved(tokenId) == operator);
    }

    // View functions
    function isLicenseValid(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0) && 
               block.timestamp <= licenses[tokenId].validUntil && 
               licenses[tokenId].isActive;
    }
    
    function getAssetCreator(string calldata assetURI) external view returns (address) {
        uint256 tokenId = _assetToToken[assetURI];
        require(tokenId != 0, "Asset not registered");
        return licenses[tokenId].creator;
    }
    
    function getCreatorAssets(address creator) external view returns (uint256[] memory) {
        return creators[creator].tokenIds;
    }
    
    function getAssetTokenId(string calldata assetURI) external view returns (uint256) {
        uint256 tokenId = _assetToToken[assetURI];
        require(tokenId != 0, "Asset not registered");
        return tokenId;
    }

    // Fee management
    function setBaseLicenseFee(uint256 newFee) external onlyOwner {
        baseLicenseFee = newFee;
        emit FeeUpdated(newFee);
    }
    
    function toggleFees(bool enabled) external onlyOwner {
        feesEnabled = enabled;
        emit FeesToggled(enabled);
    }
    
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    // Override transfer functions to check license validity
    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(isLicenseValid(tokenId), "Cannot transfer invalid license");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(isLicenseValid(tokenId), "Cannot transfer invalid license");
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
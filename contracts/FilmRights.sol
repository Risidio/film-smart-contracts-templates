// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FilmRights is ERC721, Ownable, ReentrancyGuard {
    struct Rights {
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

    // Rights data by token ID
    mapping(uint256 => Rights) public licenses;
    
    // Creator data by address
    mapping(address => Creator) public creators;
    
    // Asset URI to token ID mapping (to prevent duplicates)
    mapping(string => uint256) private _assetToToken;

    // Store the excess payable amount from a user
    mapping(address => uint256) private _pendingRefunds;
    
    // Rights fee configuration
    uint256 public baseRightsFee;
    bool public feesEnabled;
    
    uint256 private _nextTokenId = 1;
    
    event RightsIssued(uint256 indexed tokenId, address indexed creator, string assetURI);
    event RightsRenewed(uint256 indexed tokenId, uint48 newValidUntil);
    event RightsDeactivated(uint256 indexed tokenId);
    event RightsReactivated(uint256 indexed tokenId);
    event CreatorRegistered(address indexed creator);
    event CreatorRevoked(address indexed creator);
    event AssetUploaded(uint256 indexed tokenId, address indexed creator, string assetURI);
    event FeeUpdated(uint256 newFee);
    event FeesToggled(bool enabled);
    event FeesWithdrawn(uint256 amount);
    event RefundWithdrawn(address indexed user, uint256 amount);

    constructor(uint256 initialFee) ERC721("FilmRights", "ALNS") Ownable(msg.sender) {
        baseRightsFee = initialFee;
        feesEnabled = true;
    }

    /**
     * @notice Registers a creator in the system.
     * @dev This function can only be called by the contract owner.
     * @param creator The address of the creator to be registered.
     * @custom:error Invalid creator address if the input address is zero.
     * @custom:error Creator already registered if the creator is already in the system.
     * @custom:event Emits a {CreatorRegistered} event upon successful registration.
     */
    function registerCreator(address creator) external onlyOwner {
        require(creator != address(0), "Invalid creator address");
        require(!creators[creator].isRegistered, "Creator already registered");
        
        creators[creator].isRegistered = true;
        emit CreatorRegistered(creator);
    }

    /**
     * @notice Revokes a creator’s registration.
     * @dev Only callable by the contract owner.
     * @param creator The address of the creator to be revoked.
     * @custom:error Creator not registered if the creator is not in the system.
     * @custom:event Emits a {CreatorRevoked} event upon successful revocation.
     */
    function revokeCreator(address creator) external onlyOwner {
        require(creators[creator].isRegistered, "Creator not registered");
        creators[creator].isRegistered = false;
        emit CreatorRevoked(creator);
    }

    /**
    * @notice Registers the owner or user who deployed the contract in the system by sending the required registration fee
    * @dev If fees are enabled, the sender must pay at least `baseRightsFee`.
     *      Any excess funds are stored for later refunds.
     * @custom:error Already registered if the sender is already in the system.
     * @custom:error Insufficient registration fee if fees are enabled and the sender does not send enough funds.
     * @custom:event Emits a {CreatorRegistered} event upon successful registration.
    */
    function registerSelf() external payable {
        require(!creators[msg.sender].isRegistered, "Already registered");
        
        if (feesEnabled) {
            require(msg.value >= baseRightsFee, "Insufficient registration fee");
        }
        
        creators[msg.sender].isRegistered = true;
        emit CreatorRegistered(msg.sender);
        
        // Return excess funds if any
        if (msg.value > baseRightsFee) {
            _pendingRefunds[msg.sender] += msg.value - baseRightsFee;
        }
    }

    /**
     * @notice Allows registered creators to upload an asset and automatically obtain a license.
     * @dev Assigns a unique token ID to the asset and issues licensing rights for a specified validity period.
     *      If fees are enabled, the sender must pay at least `baseRightsFee`. Any excess funds are refunded.
     * @param assetURI The unique URI of the asset being uploaded.
     * @param assetMetadata The metadata describing the asset that is generated alongside the Asset URI when uploaded.
     * @param validityPeriod The duration (in seconds) for which the license remains valid.
     * @return tokenId The unique token ID assigned to the uploaded asset.
     * 
     * @custom:error Not a registered creator if the sender is not registered in the system.
     * @custom:error Asset URI cannot be empty if the provided URI is an empty string.
     * @custom:error Asset metadata value cannot be empty if the metadata is an empty string.
     * @custom:error Asset already registered if the asset URI has already been used.
     * @custom:error Validity period is too long if it exceeds 10 years.
     * @custom:error Validity must be greater than 0 if a zero value is provided.
     * @custom:error Insufficient license fee if fees are enabled and the sender does not provide enough ETH.
     * 
     * @custom:event Emits an {AssetUploaded} event when an asset is successfully uploaded.
     * @custom:event Emits a {RightsIssued} event when a licensing right is granted.
     */
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
        require(bytes(assetMetadata).length > 0, "Asset metadata value cannot be empty");
        require(_assetToToken[assetURI] == 0, "Asset already registered");
        require(validityPeriod <= 10 * 365 days, "Validity period is too long.");
        require(validityPeriod > 0, "Validity must be greater than 0.");
        
        // Check if fees need to be paid
        if (feesEnabled) {
            require(msg.value >= baseRightsFee, "Insufficient license fee");
        }
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        
        // Store license information
        licenses[tokenId] = Rights({
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
        emit RightsIssued(tokenId, msg.sender, assetURI);
        
        // Return excess funds if any
        if (msg.value > baseRightsFee) {
            payable(msg.sender).transfer(msg.value - baseRightsFee);
        }
        
        return tokenId;
    }

    /**
     * @notice Allows the admin to manually issue a license to a registered creator for edge cases.
     * @dev This function is restricted to the contract owner and can be used to grant licensing rights
     *      in exceptional cases where a creator cannot self-register or upload their asset.
     * @param creator The address of the creator receiving the license.
     * @param assetURI The unique URI of the asset being licensed.
     * @param assetMetadata Additional metadata describing the asset.
     * @param validityPeriod The duration (in seconds) for which the license remains valid.
     * @return tokenId The unique token ID assigned to the licensed asset.
     * 
     * @custom:error Not a registered creator if the provided creator address is not registered.
     * @custom:error Asset URI cannot be empty if the provided URI is an empty string.
     * @custom:error Asset already registered if the asset URI has already been used.
     * @custom:error Validity period is too long if it exceeds 10 years.
     * @custom:error Validity must be greater than 0 if a zero value is provided.
     * 
     * @custom:event Emits an {AssetUploaded} event when an asset is successfully licensed.
     * @custom:event Emits a {RightsIssued} event when licensing rights are granted to the creator.
     */
    function issueRights(
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
        require(validityPeriod <= 10 * 365 days, "Validity period is too long.");
        require(validityPeriod > 0, "Validity must be greater than 0.");

        uint256 tokenId = _nextTokenId++;
        _safeMint(creator, tokenId);
        
        licenses[tokenId] = Rights({
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
        emit RightsIssued(tokenId, creator, assetURI);
        
        return tokenId;
    }

    /**
     * @notice Allows rights holders to renew the validity of their licensing rights.
     * @dev Extends the expiration date of an active license by the specified `additionalTime`.
     *      If fees are enabled, the sender must pay at least `baseRightsFee`. Excess funds are refunded.
     * @param tokenId The unique ID of the licensed asset.
     * @param additionalTime The additional duration (in seconds) to extend the license.
     * 
     * @custom:error Not owner or approved if the caller is not authorised to manage the license.
     * @custom:error Film Rights is not active if the license is currently inactive.
     * @custom:error Additional time must be greater than 0 if a zero value is provided.
     * @custom:error Insufficient renewal fee if fees are enabled and the sender does not provide enough ETH.
     * 
     * @custom:event Emits a {RightsRenewed} event upon successful renewal.
     */
    function renewRights(uint256 tokenId, uint48 additionalTime) external payable {
        require(_isAuthorized(msg.sender, tokenId), "Not owner or approved");
        require(licenses[tokenId].isActive, "Film Rights is not active");
        require(additionalTime > 0, "Additional time must be greater than 0");
        
        if (feesEnabled) {
            require(msg.value >= baseRightsFee, "Insufficient renewal fee");
        }
        
        // Update expiration date
        licenses[tokenId].validUntil += additionalTime;
        
        emit RightsRenewed(tokenId, licenses[tokenId].validUntil);
        
        // Return excess funds if any
        if (msg.value > baseRightsFee) {
            payable(msg.sender).transfer(msg.value - baseRightsFee);
        }
    }
    
    /**
     * @notice Allows authorised users or the contract owner to deactivate an active license.
     * @dev Once deactivated, the license can only be reactivated by the contract owner.
     * @param tokenId The unique ID of the licensed asset.
     * 
     * @custom:error Not authorised if the caller is neither the owner nor an approved user of the license.
     * @custom:error Film Rights already inactive if the license is already deactivated.
     * 
     * @custom:event Emits a {RightsDeactivated} event upon successful deactivation.
     */
    function deactivateRights(uint256 tokenId) external {
        require(_isAuthorized(msg.sender, tokenId) || msg.sender == owner(), "Not authorized");
        require(licenses[tokenId].isActive, "Film Rights already inactive");
        
        licenses[tokenId].isActive = false;
        emit RightsDeactivated(tokenId);
    }
    
    /**
     * @notice Allows the contract owner to reactivate a previously deactivated license.
     * @dev Only the owner can call this function to restore an inactive license.
     * @param tokenId The unique ID of the licensed asset.
     * 
     * @custom:error Film Rights already active if the license is not currently inactive.
     * 
     * @custom:event Emits a {RightsReactivated} event upon successful reactivation.
     */
    function reactivateRights(uint256 tokenId) external onlyOwner {
        require(!licenses[tokenId].isActive, "Film Rights already active");
        
        licenses[tokenId].isActive = true;
        emit RightsReactivated(tokenId);
    }

    /**
     * @notice Checks if an address is authorised to manage a specific token.
     * @dev The address is authorised if it is the owner, approved for all, or specifically approved.
     * @param operator The address requesting authorization.
     * @param tokenId The unique ID of the asset token.
     * @return bool True if the operator is authorised, false otherwise.
     */
    function _isAuthorized(address operator, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (operator == owner || 
                isApprovedForAll(owner, operator) || 
                getApproved(tokenId) == operator);
    }

    /**
     * @notice Checks if a specific asset license is currently valid.
     * @dev A license is valid if the asset exists, is still within its validity period, and is active.
     * @param tokenId The unique ID of the licensed asset.
     * @return bool True if the license is valid, false otherwise.
     */
    function isRightsValid(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0) && 
               block.timestamp <= licenses[tokenId].validUntil && 
               licenses[tokenId].isActive;
    }
    
    /**
     * @notice Retrieves the creator address of a registered asset.
     * @dev Requires that the asset has been registered.
     * @param assetURI The unique URI of the asset.
     * @return address The address of the asset's creator.
     * 
     * @custom:error Asset not registered if the provided asset URI does not exist.
     */
    function getAssetCreator(string calldata assetURI) external view returns (address) {
        uint256 tokenId = _assetToToken[assetURI];
        require(tokenId != 0, "Asset not registered");
        return licenses[tokenId].creator;
    }
    
    /**
     * @notice Retrieves all asset token IDs associated with a specific creator.
     * @param creator The address of the creator.
     * @return uint256[] An array of token IDs owned by the creator.
     */
    function getCreatorAssets(address creator) external view returns (uint256[] memory) {
        return creators[creator].tokenIds;
    }
    
    /**
     * @notice Retrieves the token ID of an asset using its unique URI.
     * @dev Requires that the asset has been registered.
     * @param assetURI The unique URI of the asset.
     * @return uint256 The token ID of the asset.
     * 
     * @custom:error Asset not registered if the provided asset URI does not exist.
     */
    function getAssetTokenId(string calldata assetURI) external view returns (uint256) {
        uint256 tokenId = _assetToToken[assetURI];
        require(tokenId != 0, "Asset not registered");
        return tokenId;
    }

    /**
     * @notice Updates the base fee required for licensing rights.
     * @dev Only the contract owner can modify the base fee.
     * @param newFee The new fee amount in wei.
     * 
     * @custom:event Emits a {FeeUpdated} event upon successful fee update.
     */
    function setbaseRightsFee(uint256 newFee) external onlyOwner {
        baseRightsFee = newFee;
        emit FeeUpdated(newFee);
    }
    
    /**
     * @notice Enables or disables the requirement for licensing fees.
     * @dev Only the contract owner can toggle the fee system.
     * @param enabled True to enable fees, false to disable them.
     * 
     * @custom:event Emits a {FeesToggled} event when the fee system is changed.
     */
    function toggleFees(bool enabled) external onlyOwner {
        feesEnabled = enabled;
        emit FeesToggled(enabled);
    }
    
    /**
     * @notice Withdraws accumulated licensing fees from the contract.
     * @dev Only the contract owner can withdraw funds.
     * 
     * @custom:error No fees to withdraw if the contract balance is zero.
     * @custom:event Emits a {FeesWithdrawn} event upon successful withdrawal.
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
        emit FeesWithdrawn(balance);
    }

    /**
     * @notice Transfers an asset license from one owner to another.
     * @dev Transfers are only allowed if the license is still valid.
     * @param from The current owner of the asset.
     * @param to The new owner of the asset.
     * @param tokenId The unique ID of the asset being transferred.
     * 
     * @custom:error Cannot transfer invalid license if the license is expired or inactive.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(isRightsValid(tokenId), "Cannot transfer invalid license");
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Safely transfers an asset license from one owner to another.
     * @dev Ensures the receiving address can handle ERC721 tokens. Transfers are only allowed if the license is valid.
     * @param from The current owner of the asset.
     * @param to The new owner of the asset.
     * @param tokenId The unique ID of the asset being transferred.
     * @param data Additional data to pass to the recipient.
     * 
     * @custom:error Cannot transfer invalid license if the license is expired or inactive.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(isRightsValid(tokenId), "Cannot transfer invalid license");
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Allows users to withdraw any pending refunds.
     * @dev Refunds are stored when users overpay for registration or renewal fees.
     * 
     * @custom:error No refund available if the caller has no pending refund balance.
     * @custom:event Emits a {RefundWithdrawn} event upon successful withdrawal.
     */
    function withdrawRefund() external {
        uint amount = _pendingRefunds[msg.sender];
        require(amount > 0, "No refund available.");
        _pendingRefunds[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit RefundWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Updates the metadata of an asset.
     * @dev Only the asset owner or an authorised user can update the metadata.
     * @param _tokenId The unique ID of the licensed asset.
     * @param _newMetadata The new metadata to associate with the asset.
     * 
     * @custom:error User not authorised if the caller is not the owner or an approved user.
     */
    function updateAssetMetadata(uint256 _tokenId, string calldata _newMetadata) external {
        require(_isAuthorized(msg.sender, _tokenId), "User not authorised");
        licenses[_tokenId].assetMetadata = _newMetadata;
    }

}
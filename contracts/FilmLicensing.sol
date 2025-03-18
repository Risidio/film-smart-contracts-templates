// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FilmLicensing
 * @dev Smart contract for managing film licensing through NFTs
 * @notice This contract allows filmmakers to register films and issue various types of licenses
 */
contract FilmLicensing is ERC721, Ownable, ReentrancyGuard {

    /**
     * @dev Types of licenses that can be issued
     * @param NonExclusive License that can be issued to multiple licensees for the same territory
     * @param Exclusive License that grants sole rights to a licensee in a specific territory
     * @param Streaming License specifically for streaming platforms
     */
    enum LicenseType { NonExclusive, Exclusive, Streaming }
    
    /**
     * @dev Territories for which licenses can be issued
     */
    enum Territory { Worldwide, NorthAmerica, Europe, AsiaPacific, LatinAmerica, Africa, Other }
    
    /**
     * @dev Structure representing a film license
     * @param creator Address of the filmmaker who created the license
     * @param validUntil Timestamp until which the license is valid
     * @param filmURI URI identifier for the film
     * @param licenseType Type of license issued
     * @param territory Geographic territory covered by the license
     * @param isActive Whether the license is currently active
     */
    struct License {
        address creator;
        uint48 validUntil;
        string filmURI;
        LicenseType licenseType;
        Territory territory;
        bool isActive;
    }
    
    /**
     * @dev Structure representing a registered film
     * @param creator Address of the filmmaker who registered the film
     * @param isRegistered Whether the film is registered in the system
     * @param exclusiveTerritories Mapping of territories to whether they have an exclusive license
     */
    struct Film {
        address creator;
        bool isRegistered;
        mapping(Territory => bool) exclusiveTerritories;
    }
    

    /**
     * @dev Mapping from license ID to License struct
     */
    mapping(uint256 => License) public licenses;
    
    /**
     * @dev Mapping of addresses to whether they are registered filmmakers
     */
    mapping(address => bool) public registeredFilmmakers;
    
    /**
     * @dev Mapping from film URI to film ID
     */
    mapping(string => uint256) private _filmToId;
    
    /**
     * @dev Mapping from film ID to Film struct
     */
    mapping(uint256 => Film) private _films;
    
    // Counters
    /**
     * @dev Counter for the next film ID to be assigned
     */
    uint256 private _nextFilmId = 1;
    
    /**
     * @dev Counter for the next license ID to be assigned
     */
    uint256 private _nextLicenseId = 1;
    
    /**
     * @dev Emitted when a filmmaker is registered
     * @param filmmaker Address of the registered filmmaker
     */
    event FilmmakerRegistered(address indexed filmmaker);
    
    /**
     * @dev Emitted when a film is registered
     * @param filmId ID assigned to the registered asset
     * @param filmURI URI identifier for the asset
     */
    event FilmRegistered(uint256 indexed filmId, string filmURI);
    
    /**
     * @dev Emitted when a license is issued
     * @param licenseId ID of the issued license
     * @param licenseType Type of license issued
     * @param territory Territory for which the license is issued
     */
    event LicenseIssued(uint256 indexed licenseId, LicenseType licenseType, Territory territory);
    
    /**
     * @dev Constructor initializes the ERC721 token with name and symbol
     */
    constructor() ERC721("FilmLicense", "FILM") Ownable(msg.sender) {}
    
    /**
     * @notice Registers a filmmaker in the system
     * @dev Only contract owner can register filmmakers
     * @param filmmaker Address of the filmmaker to register
     */
    function registerFilmmaker(address filmmaker) external onlyOwner {
        require(!registeredFilmmakers[filmmaker], "Already registered");
        registeredFilmmakers[filmmaker] = true;
        emit FilmmakerRegistered(filmmaker);
    }
    
    /**
     * @notice Registers a film in the system
     * @dev Only registered filmmakers can register films
     * @param filmURI URI identifier for the asset
     * @return filmId ID assigned to the registered asset
     */
    function registerFilm(string calldata filmURI) external returns (uint256) {
        require(registeredFilmmakers[msg.sender], "Not registered filmmaker");
        require(_filmToId[filmURI] == 0, "Film already registered");
        require(bytes(filmURI).length > 0, "URI of the film must be entered");
        
        uint256 filmId = _nextFilmId++;
        
        Film storage film = _films[filmId];
        film.creator = msg.sender;
        film.isRegistered = true;
        
        _filmToId[filmURI] = filmId;
        
        emit FilmRegistered(filmId, filmURI);
        return filmId;
    }

    /**
     * @dev Checks if a duplicate license exists for the same film, type, and territory
     * @param filmURI The URI of the film
     * @param licenseType The type of license
     * @param territory The territory for the license
     * @return bool True if a duplicate license exists
     */
    function _duplicateLicenseExists(
        string calldata filmURI,
        LicenseType licenseType, 
        Territory territory
    ) 
        internal 
        view 
        returns (bool) 
    {
        for (uint256 i = 1; i < _nextLicenseId; i++) {
            License storage license = licenses[i];
            
            // Check if this is an active license for the same film
            if (keccak256(bytes(license.filmURI)) == keccak256(bytes(filmURI)) && 
                license.isActive &&
                block.timestamp <= license.validUntil) {
                
                // For exclusive licenses, we already check territory in issueLicense
                // For non-exclusive and streaming, prevent duplicates of same type in same territory
                if (license.licenseType == licenseType && license.territory == territory) {
                    return true;
                }
            }
        }
        return false;
    }
    
    /**
     * @notice Issues a license for a film
     * @dev Only the film creator can issue licenses
     * @param filmURI The URI of the film
     * @param licensee Address that will receive the license
     * @param validityPeriod Duration for which the license is valid (in seconds)
     * @param licenseType Type of license to issue
     * @param territory Territory for which the license is issued
     * @return licenseId ID of the issued license
     */
    function issueLicense(
        string calldata filmURI,
        address licensee,
        uint48 validityPeriod,
        LicenseType licenseType,
        Territory territory
    ) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        uint256 filmId = _filmToId[filmURI];
        require(filmId != 0, "Film not registered");
        require(_films[filmId].creator == msg.sender, "Not film creator");
        require(validityPeriod <= 10 * 365 days, "Validity period is too long");
        
        // Exclusive license territory check
        if (licenseType == LicenseType.Exclusive) {
            require(!_films[filmId].exclusiveTerritories[territory], "Territory has exclusive license");
            _films[filmId].exclusiveTerritories[territory] = true;
        } else {
            // For non-exclusive and streaming, check for duplicates
            require(!_duplicateLicenseExists(filmURI, licenseType, territory), 
                    "Duplicate license exists for this film, type and territory");
        }
        
        uint256 licenseId = _nextLicenseId++;
        _safeMint(licensee, licenseId);
        
        licenses[licenseId] = License({
            creator: msg.sender,
            validUntil: uint48(block.timestamp) + validityPeriod,
            filmURI: filmURI,
            licenseType: licenseType,
            territory: territory,
            isActive: true
        });
        
        emit LicenseIssued(licenseId, licenseType, territory);
        return licenseId;
    }
    
    /**
     * @notice Checks if a license is valid
     * @dev A license is valid if it has an owner, is not expired, and is active
     * @param licenseId ID of the license to check
     * @return bool True if the license is valid
     */
    function isLicenseValid(uint256 licenseId) public view returns (bool) {
        return _ownerOf(licenseId) != address(0) && 
               block.timestamp <= licenses[licenseId].validUntil && 
               licenses[licenseId].isActive;
    }
    
    /**
     * @notice Renews a license by extending its validity period
     * @dev Only the license owner can renew a license
     * @param licenseId ID of the license to renew
     * @param additionalTime Additional time to extend the license (in seconds)
     */
    function renewLicense(uint256 licenseId, uint48 additionalTime) external {
        require(_ownerOf(licenseId) == msg.sender, "Not license owner");
        require(licenses[licenseId].isActive, "License not active");
        require(additionalTime > 0, "Additional time must be greater than 0");
        
        licenses[licenseId].validUntil += additionalTime;
    }
    
    /**
     * @notice Deactivates a license
     * @dev Can be called by the license creator, contract owner, or license owner
     * @param licenseId ID of the license to deactivate
     */
    function deactivateLicense(uint256 licenseId) external {
        require(
            licenses[licenseId].creator == msg.sender || 
            owner() == msg.sender || 
            _ownerOf(licenseId) == msg.sender, 
            "Not authorized"
        );
        
        licenses[licenseId].isActive = false;
        
        // Free up exclusive territory if needed
        if (licenses[licenseId].licenseType == LicenseType.Exclusive) {
            uint256 filmId = _filmToId[licenses[licenseId].filmURI];
            _films[filmId].exclusiveTerritories[licenses[licenseId].territory] = false;
        }
    }
    
    /**
     * @notice Overrides ERC721 transferFrom to check license validity
     * @dev Requires the license to be valid before transfer
     * @param from Address transferring the license
     * @param to Address receiving the license
     * @param licenseId ID of the license being transferred
     */
    function transferFrom(address from, address to, uint256 licenseId) public override {
        require(isLicenseValid(licenseId), "Invalid license");
        super.transferFrom(from, to, licenseId);
    }

    /**
     * @notice Overrides ERC721 safeTransferFrom to check license validity
     * @dev Requires the license to be valid before transfer
     * @param from Address transferring the license
     * @param to Address receiving the license
     * @param licenseId ID of the license being transferred
     * @param data Additional data with no specified format
     */
    function safeTransferFrom(address from, address to, uint256 licenseId, bytes memory data) public override {
        require(isLicenseValid(licenseId), "Invalid license");
        super.safeTransferFrom(from, to, licenseId, data);
    }

    /**
     * @notice Checks if a film URI already has active licenses
     * @dev Returns both a boolean indicating if licenses exist and an array of license IDs
     * @param filmURI The URI of the film to check
     * @return isLicensed Whether the film has any active licenses
     * @return licenseIds Array of active license IDs for this film
     */
    function getFilmLicenses(string calldata filmURI) 
        external 
        view 
        returns (bool isLicensed, uint256[] memory licenseIds) 
    {
        uint256 filmId = _filmToId[filmURI];
        
        // If film isn't registered, it can't be licensed
        if (filmId == 0) {
            return (false, new uint256[](0));
        }
        
        // Count active licenses to create appropriate array size
        uint256 activeCount = 0;
        for (uint256 i = 1; i < _nextLicenseId; i++) {
            if (keccak256(bytes(licenses[i].filmURI)) == keccak256(bytes(filmURI)) && 
                licenses[i].isActive &&
                block.timestamp <= licenses[i].validUntil) {
                activeCount++;
            }
        }
        
        // If no active licenses found
        if (activeCount == 0) {
            return (false, new uint256[](0));
        }
        
        // Fill array with active license IDs
        licenseIds = new uint256[](activeCount);
        uint256 arrayIndex = 0;
        
        for (uint256 i = 1; i < _nextLicenseId; i++) {
            if (keccak256(bytes(licenses[i].filmURI)) == keccak256(bytes(filmURI)) && 
                licenses[i].isActive &&
                block.timestamp <= licenses[i].validUntil) {
                licenseIds[arrayIndex] = i;
                arrayIndex++;
            }
        }
        
        return (true, licenseIds);
    }

    /**
     * @notice Checks if a film has an exclusive license in a specific territory
     * @dev Returns a boolean indicating if an exclusive license exists
     * @param filmURI The URI of the film to check
     * @param territory The territory to check for exclusive licenses
     * @return hasExclusiveLicense Whether the film has an active exclusive license in the territory
     */
    function hasExclusiveLicense(string calldata filmURI, Territory territory) 
        external 
        view 
        returns (bool) 
    {
        uint256 filmId = _filmToId[filmURI];
        
        // If film isn't registered, it can't have exclusive licenses
        if (filmId == 0) {
            return false;
        }
        
        // Check if territory is marked as having an exclusive license
        return _films[filmId].exclusiveTerritories[territory];
    }
}
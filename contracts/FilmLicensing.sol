// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FilmLicensing is ERC721, Ownable, ReentrancyGuard {

    enum LicenseType { NonExclusive, Exclusive, Streaming }
    enum Territory { Worldwide, NorthAmerica, Europe, AsiaPacific, LatinAmerica, Africa, Other }
    

    struct License {
        address creator;
        uint48 validUntil;
        string filmURI;
        LicenseType licenseType;
        Territory territory;
        bool isActive;
    }
    
    struct Film {
        address creator;
        bool isRegistered;
        mapping(Territory => bool) exclusiveTerritories;
    }
    

    mapping(uint256 => License) public licenses;
    mapping(address => bool) public registeredFilmmakers;
    mapping(string => uint256) private _filmToId;
    mapping(uint256 => Film) private _films;
    

    uint256 private _nextFilmId = 1;
    uint256 private _nextLicenseId = 1;
    

    event FilmmakerRegistered(address indexed filmmaker);
    event FilmRegistered(uint256 indexed filmId, string filmURI);
    event LicenseIssued(uint256 indexed licenseId, LicenseType licenseType, Territory territory);
    
    constructor() ERC721("FilmLicense", "FILM") Ownable(msg.sender) {}
    
    // 1. FILMMAKER REGISTRATION
    function registerFilmmaker(address filmmaker) external onlyOwner {
        require(!registeredFilmmakers[filmmaker], "Already registered");
        registeredFilmmakers[filmmaker] = true;
        emit FilmmakerRegistered(filmmaker);
    }
    
    // 2. FILM REGISTRATION
    function registerFilm(string calldata filmURI) external returns (uint256) {
        require(registeredFilmmakers[msg.sender], "Not registered filmmaker");
        require(_filmToId[filmURI] == 0, "Film already registered");
        
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
    * @param filmURI The URI of the film/asset
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
    
    // 3. LICENSE ISSUANCE (combined function for all types)
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
    require(filmId != 0, "Film not registered. Please register your film");
    require(_films[filmId].creator == msg.sender, "Not the film creator");
    
    // Exclusive license territory check
    if (licenseType == LicenseType.Exclusive) {
        require(!_films[filmId].exclusiveTerritories[territory], "Territory already has an exclusive license");
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
    
    // 4. LICENSE VALIDITY CHECK
    function isLicenseValid(uint256 licenseId) public view returns (bool) {
        return _ownerOf(licenseId) != address(0) && 
               block.timestamp <= licenses[licenseId].validUntil && 
               licenses[licenseId].isActive;
    }
    
    // 5. LICENSE RENEWAL
    function renewLicense(uint256 licenseId, uint48 additionalTime) external {
        require(_ownerOf(licenseId) == msg.sender, "Not license owner");
        require(licenses[licenseId].isActive, "License not active");
        
        licenses[licenseId].validUntil += additionalTime;
    }
    
    // 6. DEACTIVATE LICENSE
    function deactivateLicense(uint256 licenseId) external {
        require(
            licenses[licenseId].creator == msg.sender || 
            owner() == msg.sender || 
            _ownerOf(licenseId) == msg.sender, 
            "Not authorised"
        );
        
        licenses[licenseId].isActive = false;
        
        if (licenses[licenseId].licenseType == LicenseType.Exclusive) {
            uint256 filmId = _filmToId[licenses[licenseId].filmURI];
            _films[filmId].exclusiveTerritories[licenses[licenseId].territory] = false;
        }
    }
    
    // Override transfer functions to check license validity
    function transferFrom(address from, address to, uint256 licenseId) public override {
        require(isLicenseValid(licenseId), "Invalid license");
        super.transferFrom(from, to, licenseId);
    }

    function safeTransferFrom(address from, address to, uint256 licenseId, bytes memory data) public override {
        require(isLicenseValid(licenseId), "Invalid license");
        super.safeTransferFrom(from, to, licenseId, data);
    }

    /**
    * @dev Checks if a film URI already has active licenses
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
    * @dev Checks if a film has an exclusive license in a specific territory
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
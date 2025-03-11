// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FilmNFT
 * @dev Manages Film Ownership using ERC-721 NFT standard.
 *
 * 📌 Features:
 * - 🎬 **Film Creation** (NFT minted when a film is registered)
 * - 🔄 **Film Ownership Transfer** (Ownership can be transferred)
 * - 🔍 **Film Metadata** (Stores film details)
 */
contract FilmNFT is ERC721URIStorage, Ownable {
    uint256 public filmCounter;

    struct RevenueShare {
        uint256 producer;
        uint256 investors;
        uint256 director;
        uint256 writer;
    }

    struct Film {
        string title;
        string assetURI;
        address producer;
        address director;
        address writer;
        address[] investors;
        RevenueShare revenueShare;
    }

    mapping(uint256 => Film) public films;
    mapping(uint256 => uint256) public filmPrices;
    RevenueShare public defaultShares;

    event FilmCreated(uint256 filmId, string title, address indexed producer);
    event FilmOwnershipTransferred(uint256 filmId, address currentOwner, address newOwner, uint256 price);

    constructor() ERC721("FilmNFT", "FILM") Ownable(msg.sender) {
        defaultShares = RevenueShare(40, 30, 20, 10);
    }

    /**
     * @dev 🎬 Creates a new film NFT and registers it in the system.
     */
    function createFilm(
        string memory _title,
        string memory _metadataURI,
        string memory _assetURI,
        address _director,
        address _writer,
        address[] memory _investors
    ) public onlyOwner returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_metadataURI).length > 0, "Metadata URI cannot be empty");

        filmCounter++;
        uint256 newFilmId = filmCounter;

        _safeMint(msg.sender, newFilmId);
        _setTokenURI(newFilmId, _metadataURI);

        films[newFilmId] = Film({
            title: _title,
            assetURI: _assetURI,
            producer: msg.sender,
            director: _director,
            writer: _writer,
            investors: _investors,
            revenueShare: defaultShares
        });

        emit FilmCreated(newFilmId, _title, msg.sender);
        return newFilmId;
    }

    /**
     * @dev Sets the price of a film NFT.
     */
    function setFilmPrice(uint256 filmId, uint256 price) external {
        require(ownerOf(filmId) == msg.sender, "Not the film owner");
        require(price > 0, "Price must be greater than zero");

        filmPrices[filmId] = price;
    }

    /**
     * @dev 🔄 Transfers film ownership.
     */
    function transferFilmOwnership(uint256 filmId, address newOwner) external payable {
        address currentOwner = ownerOf(filmId);
        require(currentOwner != newOwner, "Already the owner");
        require(msg.sender == newOwner, "Only the buyer can initiate transfer");
        require(msg.value > 0, "Payment required");

        uint256 filmPrice = filmPrices[filmId]; // Get the preset film price
        require(msg.value >= filmPrice, "Insufficient payment");

        // Transfer payment to the current owner
        payable(currentOwner).transfer(msg.value);

        // Transfer ownership
        _transfer(currentOwner, newOwner, filmId);

        emit FilmOwnershipTransferred(
            filmId,
            currentOwner,
            newOwner,
            msg.value
        );

        require(ownerOf(filmId) == msg.sender, "Not the film owner");
        _transfer(msg.sender, newOwner, filmId);
    }

    /**
     * @dev 📊 Gets the revenue share distribution for a film.
     */
    function getRevenueShare(
        uint256 filmId
    )
        external
        view
        returns (
            uint256 producer,
            uint256 investors,
            uint256 director,
            uint256 writer
        )
    {
        require(filmId > 0 && filmId <= filmCounter, "Invalid film ID");

        RevenueShare memory share = films[filmId].revenueShare;
        return (share.producer, share.investors, share.director, share.writer);
    }

    /**
     * @dev 🔍 Gets film details.
     */
    function getFilmDetails(
        uint256 filmId
    ) external view returns (string memory, address) {
        Film memory film = films[filmId];
        return (film.title, film.producer);
    }
}

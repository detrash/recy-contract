// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title Recy Certificate
 * @author Edward Lee - [neddy34](https://github.com/neddy34)
 * @notice The Recy Certificate is awarded to companies that commit to locking a specified amount of cRECYs (a digital asset)
 * for a certain period to demonstrate their commitment to reducing waste.
 * This certificate acts as an assurance to stakeholders that the company is actively engaged in sustainable waste practices.
 */
contract RecyCertificate is ERC721URIStorage, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    string baseURI;
    string public baseExtension = ".json";

    error OnlyOneNFTPerAccount();

    constructor() ERC721("Recy Certificate", "RecyCert") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());
    }

    /**
     * @notice Mint a new NFT for the recipient.
     * @param recipient The address of the recipient of the NFT.
     */
    function mint(
        address recipient
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();

        uint256 balance = balanceOf(recipient);

        // Only one NFT per account.
        if (balance > 0) {
            revert OnlyOneNFTPerAccount();
        }

        _mint(recipient, newItemId);
        _setTokenURI(
            newItemId,
            string(abi.encodePacked(recipient, baseExtension))
        );

        return newItemId;
    }

    /**
     * @notice Burn an NFT by its token ID.
     * @param tokenId The ID of the NFT to burn.
     */
    function burnByTokenId(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    /**
     * @notice Burn an NFT by the user's address.
     * @param user The address of the user to burn.
     */
    function burn(address user) public onlyRole(BURNER_ROLE) {
        uint256 tokenId = tokenOfOwnerByIndex(user, 0);

        _burn(tokenId);
    }

    /**
     * @notice Change the base URI and extension for the NFTs.
     * @param _newBaseURI The new base URI for the NFTs.
     * @param _baseExtension The new base extension for the NFTs.
     */
    function setURIOptions(
        string memory _newBaseURI,
        string memory _baseExtension
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _newBaseURI;
        baseExtension = _baseExtension;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // Transfer is disabled
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * @notice Get the URI for the NFT with the given ID.
     * @param tokenId The ID of the NFT to get the URI for.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract FCWERC721 is ERC721URIStorage, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    string baseURI;
    string public baseExtension = ".json";

    error OnlyOneNFTPerAccount();

    constructor() ERC721("DeTrash Certificate", "DeTrash") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());
    }

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

    function burnByTokenId(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    function burn(address user) public onlyRole(BURNER_ROLE) {
        uint256 tokenId = tokenOfOwnerByIndex(user, 0);

        _burn(tokenId);
    }

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

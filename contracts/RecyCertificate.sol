// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./ERC721GenericMetadata.sol";

/**
 * @title Recy Certificate
 * @author Edward Lee - [neddy34](https://github.com/neddy34)
 * @author Fausto Vanin - [faustovanin](https://github.com/faustovanin)
 * @notice The Recy Certificate is awarded to companies that commit to locking a specified amount of cRECYs (a digital asset)
 * for a certain period to demonstrate their commitment to reducing waste.
 * This certificate acts as an assurance to stakeholders that the company is actively engaged in sustainable waste practices.
 */
contract RecyCertificate is
    ERC721EnumerableUpgradeable, 
    ERC721GenericMetadata {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    error OnlyOneNFTPerAccount();

    function __RecyCertificate_init(address _admin)  internal 
    {
        __ERC721_init("Recy Certificate", "RecyCert");
        __ERC721GenericMetadata_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());
    }

    function initialize(address admin) 
        external
        initializer 
    {
        __RecyCertificate_init(admin);
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

        _mint(recipient, newItemId);
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
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // Transfer is disabled
        revert("Transfer is disabled");
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable) {
        super._burn(tokenId);
    }

    function setSchema(
        string memory _version,
        Trait[] memory _traits
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        _setSchema(_version, _traits);
    }

    function assemble(
        uint256 _tokenId,
        string memory _version
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        _assemble(_tokenId, _version);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(AccessControlEnumerableUpgradeable).interfaceId ||
            interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./utils/ModifiedEnumerableMapUpgradeable.sol";
import "./IERC721GenericMetadata.sol";

/**
 * @title Generic metadata contract to store nft attributes
 * @notice This contract allows for a version-controlled attributes, which are saved
 * as an schema in the allowedTraits mapping. NFTs are then saved under their current
 * version.
 * The attributes reading is tolerant to missing attributes or values. Overall, updating
 * a schema should work fine only when reducing the number of traits (that is, "deleting")
 * a trait. For updates that rename or add traits, the best course of action is to create
 * a new version and migrate items to the new schema
 * To update an item's attributes, one should call assemble() again.
 */
contract ERC721GenericMetadata is Initializable, IGenericMetadata, AccessControlEnumerableUpgradeable {

    using Strings for uint256;
    using ModifiedEnumerableMapUpgradeable for ModifiedEnumerableMapUpgradeable.StringToBytesMap;

    mapping(string => Trait[]) internal defaultTraits;
    mapping(uint256 => string) internal versionByToken;
    mapping(uint256 => ModifiedEnumerableMapUpgradeable.StringToBytesMap) internal appliedTraits;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function __ERC721GenericMetadata_init() internal onlyInitializing {}

    /**
     * @dev sets the schema of a version, either new or existing ones
     * @param _version version name
     * @param _traits array of trait names
     */
    function _setSchema(
        string memory _version,
        Trait[] memory _traits
    )
        internal
    {
        require(bytes(_version).length > 0, "ERC721GenericMetadata: invalid schema name");

        for (uint8 i = 0; i < _traits.length; i++) {
            defaultTraits[_version].push(_traits[i]);
        }
    }

    /**
     * @dev stores traits of an item. This method is tolerant for missing traits
     * and traits outside schema
     * @param _tokenId the item id
     * @param _version the version to assemble
     */
    function _assemble(
        uint256 _tokenId,
        string memory _version
    )
        internal
    {
        versionByToken[_tokenId] = _version;

        for (uint256 i = 0; i < defaultTraits[_version].length; i++) {
            // @todo unused var
            (bool traitExists,) = appliedTraits[_tokenId].tryGet(defaultTraits[_version][i].key);

            if (!traitExists) {
                appliedTraits[_tokenId].set(defaultTraits[_version][i].key, defaultTraits[_version][i].value);
            }
        }
    }

    function _getAttribute(
        uint _tokenId,
        string memory _name
    )
        internal
        view
        returns (string memory)
    {
        return appliedTraits[_tokenId].get(_name);
    }

    function _hasAttribute(
        uint256 _tokenId,
        string memory _name
    )
        internal
        view
        returns(bool)
    {
        return appliedTraits[_tokenId].contains(_name);
    }

    function setAttribute(
        uint256 _tokenId,
        string memory _trait,
        string memory  _value
    )
        public
        onlyRole(OPERATOR_ROLE)
    {
        appliedTraits[_tokenId].set(_trait, _value);
    }

    function getAttribute(
        uint256 _tokenId,
        string memory _trait
    )
        public
        view
        returns (string memory)
    {
        return appliedTraits[_tokenId].get(_trait);
    }

    /**
     * @dev returns the item attributes if present in version schema
     * @param _tokenId the item id
     * @return Trait[] item attributes
     */
    function attributes(
        uint256 _tokenId
    )
        public
        view
        returns (Trait[] memory)
    {
        require(bytes(versionByToken[_tokenId]).length != 0, "ERC721GenericMetadata: item not found");

        Trait[] memory traits = defaultTraits[versionByToken[_tokenId]];

        Trait[] memory attr = new Trait[](traits.length);

        for (uint8 i = 0; i < traits.length; i++) {
            (bool traitFound, string memory value) = appliedTraits[_tokenId].tryGet(traits[i].key);
            if (traitFound) attr[i] = Trait(traits[i].key, value);
        }

        return attr;
    }

    /**
     * @dev returns allowed traits under a version
     * @param _version the version name
     * @return string[] attribute names
     */
    function schema(
        string calldata _version
    )
        public
        view
        returns (Trait[] memory)
    {
        return defaultTraits[_version];
    }

    function isSchema(
        string memory _schema
    ) public view returns(bool) {
        return  defaultTraits[_schema].length > 0;
    }

    uint256[50] private __gap;

}
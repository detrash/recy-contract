// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IGenericMetadata{

    struct Trait {
        string key;
        string value;
    }

    function setAttribute(
        uint256 _tokenId,
        string memory _trait,
        string memory _value
    ) external;

    function getAttribute(
        uint256 _tokenId,
        string memory _trait
    ) external view returns (string memory);

    function attributes(
        uint256 _tokenId
    ) external view returns (Trait[] memory);

    function schema(
        string calldata _version
    ) external view returns (Trait[] memory);

}

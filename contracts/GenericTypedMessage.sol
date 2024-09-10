// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

/**
 * @dev Helper contract to verify signed typed messages
 */
import "hardhat/console.sol";

contract GenericTypedMessage is EIP712Upgradeable {

    mapping(address => mapping(bytes32 => bool)) internal _authorizationStates;

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    function __GenericTypedMessage_init() internal onlyInitializing {
        __EIP712_init("GenericTypedMessage", "1");
    }

    /**
     * @dev check whether a typed data signature is valid.
     * `_structHash` should be calculated using the type hash and typed data parameters, eg.:
     *    bytes32 _PERMIT_TYPEHASH = keccak256("Permit(address owner,bytes32 authorization,address operator,bool approved,bytes32 nonce,uint256 deadline)");
     *    bytes32 structHash = keccak256(
     *       abi.encode(
     *           _PERMIT_TYPEHASH, => typehash
     *           signer, => typed data param
     *           authorization, => typed data param
     *           operator, => typed data param
     *           approved, => typed data param
     *           nonce, => typed data param
     *           deadline => typed data param
     *       )
     *   );
     * This implementation uses non-sequential authorizations instead of nonces. Each time
     * the function processes a valid signature, the authorization is burned and cannot be used again.
     * @notice It's the inheriting contract resposibility to include the authorization in the struct hash
     * otherwise the authorization logic will have no effect
     * @param _structHash keccak256-abi-encoded message
     * @param _authorization one-time authorization
     * @param _deadline signature expiration time
     * @param _signer the message signer
     * @param _v signature v
     * @param _r signature r
     * @param _s signature s
     * @return true if checks passed
     */
    function _verifyTypedMessage(
        bytes32 _structHash,
        bytes32 _authorization,
        uint256 _deadline,
        address _signer,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        view
        returns (bool)
    {
        require(block.timestamp <= _deadline, "GenericTypedMessage: expired deadline");
        require(
            !_authorizationStates[_signer][_authorization],
            "GenericTypedMessage: authorization already used"
        );

        bytes32 hash = _hashTypedDataV4(_structHash);

        address signer = ECDSAUpgradeable.recover(hash, _v, _r, _s);
        require(signer == _signer, "GenericTypedMessage: signer does not match signature");

        return true;
    }

    /**
     * @dev Burns a message for no furtrher call
     * @param _structHash keccak256-abi-encoded message
     * @param _authorization one-time authorization
     * @param _deadline signature expiration time
     * @param _signer the message signer
     * @param _v signature v
     * @param _r signature r
     * @param _s signature s
     */
    function _burnMessage(
        bytes32 _structHash,
        bytes32 _authorization,
        uint256 _deadline,
        address _signer,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) 
        internal
    {
        if (_verifyTypedMessage(_structHash, _authorization, _deadline, _signer, _v, _r, _s)) {

        }
        _authorizationStates[_signer][_authorization] = true;

        emit AuthorizationUsed(_signer, _authorization);
    }

    /**
     * @dev returns the state of a given authorization
     * @param authorizer signer address
     * @param authorization the authorization
     * @return the autorization state
     */
    function authorizationState(address authorizer, bytes32 authorization)
        external
        view
        returns (bool)
    {
        return _authorizationStates[authorizer][authorization];
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

}

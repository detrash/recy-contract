// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20Upgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./RecyCertificate.sol";
import { GenericTypedMessage } from "./GenericTypedMessage.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
/**
 * @title TimeLock contract for cRECY ERC20 token
 * @author Edward Lee - [neddy34](https://github.com/neddy34)
 * @notice This contract is used to lock cRECY tokens for a period of time.
 * Currently only locks the token, additional features like staking and rewards will be added in the future.
 */
contract TimeLock is
    Initializable,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    GenericTypedMessage
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Strings for uint256;
    using Strings for uint8;
    using Strings for uint16;
    using Strings for uint32;

    bytes32 public constant _LOCK_TYPEHASH = keccak256("CertificateAuthorization(bytes32 institution,uint8 tons,uint16 baseYear,uint8 baseMonth,uint8 timespan,address signer,bytes32 authorization,uint256 deadline)");
    bytes32 public constant _UNLOCK_TYPEHASH = keccak256("UnlockAuthorization(address lockAccount,address signer,bytes32 authorization,uint256 deadline)");
    struct Lock {
        uint256 amount;
        uint256 lockedAt;
        uint256 unlockedAt;
        bool earlyWithdrawalAllowed;
    }

    struct UserLock {
        uint256 lockCount;
        uint256 totalLocked;
        uint256 totalUnlocked;
        mapping(uint256 => Lock) locks;
    }

    struct CertificateAuthorization {
        bytes32 institution;
        uint8 tons;
        uint16 baseYear;
        uint8 baseMonth;
        uint8 timespan;
        address signer;
        bytes32 authorization;
        uint256 deadline;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    IERC20Upgradeable public cRECY;
    RecyCertificate public certNFT;

    uint256 public defaultLockPeriod;
    uint256 public totalLocked;
    uint256 public totalUnlocked;
    uint256 public totalLockers;

    mapping(address => UserLock) private _userLocks;
    mapping(uint256 => address) private _lockersByIndex;
    mapping(uint256 => uint256) private _lockToToken;

    event Locked(
        address indexed user,
        uint256 amount,
        uint256 lockedAt,
        uint256 lockIndex
    );
    event Unlocked(
        address indexed user,
        uint256 amount,
        uint256 unlockedAt,
        uint256 lockIndex
    );
    event CertificateCreated(
        CertificateAuthorization certificate,
        address lockSigner,
        uint256 valueLocked
    );

    error InLockPeriod(uint256 unlockTime);
    error AlreadyUnlocked();
    error InvalidMonth(uint8 month);
    error InvalidSigner(address signer);

    string public constant INITIAL_SCHEMA = "lock-v0";
    string public defaultSchema;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _cRECY, address _recyCert, address admin) external initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __GenericTypedMessage_init();

        cRECY = IERC20Upgradeable(_cRECY);
        certNFT = RecyCertificate(_recyCert);
        defaultLockPeriod = 2 * 365 days;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, admin);
    }

    function setupTraits() external onlyRole(ADMIN_ROLE) {
        ERC721GenericMetadata.Trait[] memory traits = new ERC721GenericMetadata.Trait[](6);
        traits[0] = IGenericMetadata.Trait({ key: "institution", value: "" });
        traits[1] = IGenericMetadata.Trait({ key: "tons", value: "" });
        traits[2] = IGenericMetadata.Trait({ key: "baseYear", value: "" });
        traits[3] = IGenericMetadata.Trait({ key: "baseMonth", value: "" });
        traits[4] = IGenericMetadata.Trait({ key: "timespan", value: "" });
        traits[5] = IGenericMetadata.Trait({ key: "status", value: "ACTIVE" });
        certNFT.setSchema(INITIAL_SCHEMA, traits);

        defaultSchema = INITIAL_SCHEMA;
    }

    /**
     * @notice Lock cRECY tokens for a period of time
     * @param amount token amount to lock
     */
    function lock(
        uint256 amount, 
        CertificateAuthorization calldata cert, 
        Signature calldata sig
    ) 
        external 
        whenNotPaused
        nonReentrant 
        returns (uint256)
    {
        if(cert.baseMonth >= 12) {
            revert InvalidMonth(cert.baseMonth);
        }
        bytes32 structHash = keccak256(
            abi.encode(
                _LOCK_TYPEHASH,
                cert.institution,
                cert.tons,
                cert.baseYear,
                cert.baseMonth,
                cert.timespan,
                cert.signer,
                cert.authorization,
                cert.deadline
            )
        );
        _verifyTypedMessage(
            structHash,
            cert.authorization,
            cert.deadline,
            cert.signer,
            sig.v,
            sig.r,
            sig.s
        );
        // require(cert.signer == owner(), "TimeLock: only owner can sign certificates");

        if (!hasRole(OPERATOR_ROLE, cert.signer) || !hasRole(ADMIN_ROLE, cert.signer)) {
            revert InvalidSigner(cert.signer);
        }

        _registerLocker(_msgSender());
        uint256 lockId = _lock(_msgSender(), amount, cert);
        _burnMessage(
            structHash,
            cert.authorization,
            cert.deadline,
            cert.signer,
            sig.v,
            sig.r,
            sig.s
        );
        return lockId;        
    }

    /**
     * @notice Unlock cRECY tokens
     * @param lockIndex index of the lock to unlock
     */
    function unlock(
        uint256 lockIndex
    ) 
        external whenNotPaused nonReentrant 
    {
        _unlock(_msgSender(), lockIndex);

        uint256 tokenId = _lockToToken[lockIndex];
        certNFT.setAttribute(tokenId, "status", "COMPLETE");
    }

    /**
     * @notice Pause the contract
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Get user locks
     * @param user address of the user
     * @return lockIndexes array of lock indexes
     * @return locks array of locks
     * @return _totalLocked total locked amount
     * @return _totalUnlocked total unlocked amount
     */
    function getUserLocks(
        address user
    )
        public
        view
        returns (
            uint256[] memory lockIndexes,
            Lock[] memory locks,
            uint256 _totalLocked,
            uint256 _totalUnlocked
        )
    {
        uint256 lockCount = _userLocks[user].lockCount;

        locks = new Lock[](lockCount);
        lockIndexes = new uint256[](lockCount);
        _totalLocked = _userLocks[user].totalLocked;
        _totalUnlocked = _userLocks[user].totalUnlocked;

        for (uint256 i = 0; i < lockCount; ) {
            locks[i] = _userLocks[user].locks[i];
            lockIndexes[i] = i;

            unchecked {
                ++i;
            }
        }

        return (lockIndexes, locks, _totalLocked, _totalUnlocked);
    }

    /**
     * @notice Get user last lock
     * @param user address of the user
     */
    function getUserLastLock(address user) public view returns (Lock memory) {
        uint256 lockCount = _userLocks[user].lockCount;
        return _userLocks[user].locks[lockCount - 1];
    }

    function _registerLocker(address _user) private {
        if (_userLocks[_user].lockCount == 0) {
            _lockersByIndex[totalLockers] = _user;
            ++totalLockers;
        }
    }

    function _lock(
        address _user, 
        uint256 _amount,
        CertificateAuthorization memory cert
    ) 
        private 
        returns (uint256) 
    {
        cRECY.safeTransferFrom(_user, address(this), _amount);
        uint256 lockedAt = block.timestamp;
        Lock memory lockToAdd = Lock({
            amount: _amount,
            lockedAt: lockedAt,
            unlockedAt: 0,
            earlyWithdrawalAllowed: false
        });

        uint256 lockIndex = _userLocks[_user].lockCount;
        _userLocks[_user].locks[lockIndex] = lockToAdd;
        _userLocks[_user].totalLocked += _amount;
        ++_userLocks[_user].lockCount;

        totalLocked += _amount;

        uint256 tokenId = certNFT.mint(msg.sender);
        certNFT.assemble(tokenId, defaultSchema);

        certNFT.setAttribute(tokenId, "institution", string(abi.encodePacked(cert.institution)));
        certNFT.setAttribute(tokenId, "tons", cert.tons.toString());
        certNFT.setAttribute(tokenId, "baseYear", cert.baseYear.toString());
        certNFT.setAttribute(tokenId, "baseMonth", cert.baseMonth.toString());
        certNFT.setAttribute(tokenId, "timespan", cert.timespan.toString());
        certNFT.setAttribute(tokenId, "status", "ACTIVE");

        _lockToToken[lockIndex] = tokenId;

        emit CertificateCreated(cert, msg.sender, _amount);
        emit Locked(_user, _amount, lockedAt, lockIndex);

        return lockIndex;
    }

    function _unlock(address _user, uint256 _lockIndex) private {
        Lock memory userLock = _userLocks[_user].locks[_lockIndex];

        if (userLock.unlockedAt != 0) {
            revert AlreadyUnlocked();
        }

        uint256 unlockTime = userLock.lockedAt + defaultLockPeriod;

        if (unlockTime > block.timestamp) {
            revert InLockPeriod(unlockTime);
        }

        _userLocks[_user].locks[_lockIndex].unlockedAt = block.timestamp;
        _userLocks[_user].totalLocked -= userLock.amount;
        _userLocks[_user].totalUnlocked += userLock.amount;

        totalLocked -= userLock.amount;
        totalUnlocked += userLock.amount;

        cRECY.safeTransfer(_user, userLock.amount);

        emit Unlocked(_user, userLock.amount, block.timestamp, _lockIndex);
    }

    function setDefaultSchema(
        string memory _schema
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        defaultSchema = _schema;
    }
    
}

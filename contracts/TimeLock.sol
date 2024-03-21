// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {CRecy} from "./CRecy.sol";
import {DeTrashCertificate} from "./ERC721Certificate.sol";

contract TimeLock is Pausable, Ownable, ReentrancyGuard {
    uint256 public lockPeriod = 2 * 365 days; // 2 years
    uint256 public emergencyLockPeriod = 365 days; // 1 year

    uint256 public minLockAmount = 100 * 10 ** 18; // 100 cRECY

    CRecy public immutable cRECY;
    DeTrashCertificate public immutable deTrashCertificate;

    struct Lock {
        uint256 amount;
        uint256 lockTime;
        uint256 unlockedAt;
    }

    // locker(address) => lockIndex => Lock
    mapping(address => mapping(uint256 => Lock)) private _locks;
    mapping(address => mapping(uint256 => bool))
        private _allowedEmergencyUnlocks;
    mapping(address => uint256) private _lockCount;
    mapping(uint256 => address) private _lockersByInidex;
    mapping(address => bool) private _blocked;

    uint256 private _totalLockers;
    uint256 private _totalLocked;
    uint256 private _totalUnlocked;

    address public signer;
    // Signature check is disabled by default
    bool private _signatureCheckEnabled;

    event LockFunds(address indexed owner, uint256 amount, uint256 lockTime);
    event UnlockFunds(
        address indexed owner,
        uint256 amount,
        uint256 unlockTime
    );

    error InvalidLockAmount();
    error InvalidTime();
    error AlreadyUnlocked();
    error Blocked();
    error InvalidSignature();

    modifier notBlocked() {
        if (_blocked[msg.sender]) {
            revert Blocked();
        }
        _;
    }

    constructor(address _cRECY, address _deTrashCertificate, address _signer) {
        cRECY = CRecy(_cRECY);
        deTrashCertificate = DeTrashCertificate(_deTrashCertificate);
        signer = _signer;
    }

    /**
     * @dev Lock cRECY token
     * @param amount amount to lock
     */
    function lock(
        uint256 amount,
        bytes memory _signature
    ) external whenNotPaused nonReentrant notBlocked {
        if (amount < minLockAmount) {
            revert InvalidLockAmount();
        }
        uint256 lockTime = block.timestamp;
        uint256 lockIndexByUser = _lockCount[msg.sender];

        if (_signatureCheckEnabled) {
            // Validate signature
            bytes32 message = keccak256(
                abi.encodePacked(lockIndexByUser, amount)
            );
            bytes32 messageHash = ECDSA.toEthSignedMessageHash(message);
            address _signer = ECDSA.recover(messageHash, _signature);

            if (_signer != signer) {
                revert InvalidSignature();
            }
        }

        Lock memory _lock = Lock({
            amount: amount,
            lockTime: lockTime,
            unlockedAt: 0
        });

        _beforeLock(_lock);

        cRECY.transferFrom(msg.sender, address(this), amount);

        if (lockIndexByUser == 0) {
            _lockersByInidex[_totalLockers] = msg.sender;
            ++_totalLockers;
        }

        _locks[msg.sender][lockIndexByUser] = _lock;
        ++_lockCount[msg.sender];
        _totalLocked += amount;

        emit LockFunds(msg.sender, amount, lockTime);

        _afterLock(_lock);
    }

    /**
     * @dev Unlock cRECY token
     * @param _lockIndex lock index by locker
     */
    function unlock(
        uint256 _lockIndex,
        bool _emergencyUnlock
    ) external whenNotPaused nonReentrant notBlocked {
        if (_emergencyUnlock) {
            if (!_canEmergencyUnlock(msg.sender, _lockIndex)) {
                revert InvalidTime();
            }
            _onEmergencyUnlock(msg.sender, _lockIndex);
        } else if (!_canUnlock(msg.sender, _lockIndex)) {
            revert InvalidTime();
        }

        _unlockUnChecked(msg.sender, _lockIndex);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Add or remove user from block list
     * @param _users The array of addresses representing the users to be added or removed from the block list.
     * @param _statuses The array of booleans representing the statuses indicating whether to block or unblock the corresponding user.
     */
    function setBlocked(
        address[] memory _users,
        bool[] memory _statuses
    ) external onlyOwner {
        require(_users.length == _statuses.length);
        uint256 len = _users.length;
        for (uint i = 0; i < len; ) {
            _blocked[_users[i]] = _statuses[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Set lock periods
     * @param _lockPeriod the duration of the lock period in seconds.
     * @param _emergencyLockPeriod the duration of the emergency lock period in seconds.
     */
    function setLockPeriod(
        uint256 _lockPeriod,
        uint256 _emergencyLockPeriod
    ) external onlyOwner {
        lockPeriod = _lockPeriod;
        emergencyLockPeriod = _emergencyLockPeriod;
    }

    /**
     * @dev Set minimum lock amount
     * @param _minLockAmount minimum amount to lock
     */
    function setMinLockAmount(uint256 _minLockAmount) external onlyOwner {
        minLockAmount = _minLockAmount;
    }

    /**
     * @dev Enables or disables the signature check for a specific operation.
     * @param _enabled A boolean value indicating whether the signature check should be enabled or disabled.
     */
    function setSignatureCheckEnabled(bool _enabled) external onlyOwner {
        _signatureCheckEnabled = _enabled;
    }

    /**
     * @dev Return the last lock of the user.
     * @param user The address of the user to query.
     */
    function getUserLastLock(address user) public view returns (Lock memory) {
        return _locks[user][_lockCount[user] - 1];
    }

    /**
     * @dev Return the lock count of the user.
     * @param user The address of the user to query.
     */
    function getUserTotalLockCount(address user) public view returns (uint256) {
        return _lockCount[user];
    }

    /**
     * @dev Return the pending locks of the user.
     * @param user The address of the user to query.
     */
    function getUserPendingLockIndexes(
        address user
    ) public view returns (uint256[] memory, Lock[] memory) {
        uint256 len = _lockCount[user];
        uint256 pendingLocksCount;
        for (uint256 i = 0; i < len; i++) {
            if (_locks[user][i].unlockedAt == 0) {
                ++pendingLocksCount;
            }
        }
        Lock[] memory locks = new Lock[](pendingLocksCount);
        uint256[] memory lockIndexes = new uint256[](pendingLocksCount);
        uint256 j;
        for (uint256 i = 0; i < len; i++) {
            if (_locks[user][i].unlockedAt == 0) {
                locks[j] = _locks[user][i];
                lockIndexes[j] = i;
                ++j;
            }
        }
        return (lockIndexes, locks);
    }

    /**
     * @dev Return the locks of the user.
     * @param user The address of the user to query.
     */
    function getUserLocks(address user) public view returns (Lock[] memory) {
        uint256 len = _lockCount[user];
        Lock[] memory locks = new Lock[](len);
        for (uint256 i = 0; i < len; i++) {
            locks[i] = _locks[user][i];
        }
        return locks;
    }

    /**
     * @dev Return the lock of the user.
     * @param user The address of the user to query.
     * @param index The index of the lock
     */
    function getUserLockByIndex(
        address user,
        uint256 index
    ) public view returns (Lock memory) {
        return _locks[user][index];
    }

    /**
     * @dev Return the locker by index.
     * @param index The index of the locker to query.
     */
    function getLockerByIndex(uint256 index) public view returns (address) {
        return _lockersByInidex[index];
    }

    function canUnlock(
        address user,
        uint256 lockIndex
    ) public view returns (bool) {
        return _canUnlock(user, lockIndex);
    }

    function canEmergencyUnlock(
        address user,
        uint256 lockIndex
    ) public view returns (bool) {
        return _canEmergencyUnlock(user, lockIndex);
    }

    function getTotalLockers() public view returns (uint256) {
        return _totalLockers;
    }

    function getTotalLocked() public view returns (uint256) {
        return _totalLocked;
    }

    function getTotalUnlocked() public view returns (uint256) {
        return _totalUnlocked;
    }

    function _unlockUnChecked(address _user, uint256 _lockIndex) internal {
        if (_locks[_user][_lockIndex].unlockedAt > 0) {
            revert AlreadyUnlocked();
        }

        uint256 lockAmount = _locks[_user][_lockIndex].amount;

        cRECY.transfer(_user, lockAmount);

        uint256 unlockTime = block.timestamp;

        _locks[_user][_lockIndex].unlockedAt = unlockTime;
        _totalLocked -= lockAmount;
        _totalUnlocked += lockAmount;

        emit UnlockFunds(_user, lockAmount, unlockTime);
    }

    function _beforeLock(Lock memory _lock) internal {}

    function _afterLock(Lock memory _lock) internal {
        uint256 balance = deTrashCertificate.balanceOf(_msgSender());

        if (balance == 0) {
            deTrashCertificate.mint(_msgSender());
        }
    }

    function _onEmergencyUnlock(address _user, uint256 _lockIndex) internal {
        uint256 balance = deTrashCertificate.balanceOf(_user);

        if (balance > 0) {
            deTrashCertificate.burn(_user);
        }
    }

    function _canUnlock(
        address _user,
        uint256 _lockIndex
    ) internal view returns (bool) {
        return
            _locks[_user][_lockIndex].lockTime + lockPeriod < block.timestamp;
    }

    function _canEmergencyUnlock(
        address _user,
        uint256 _lockIndex
    ) internal view returns (bool) {
        return
            _allowedEmergencyUnlocks[msg.sender][_lockIndex] &&
            _locks[_user][_lockIndex].lockTime + emergencyLockPeriod <
            block.timestamp;
    }
}

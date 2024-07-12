// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20Upgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "hardhat/console.sol";

/**
 * @title TimeLock contract for cRECY ERC20 token
 * @author Edward Lee - [neddy34](https://github.com/neddy34)
 * @notice This contract is used to lock cRECY tokens for a period of time.
 * Currently only locks the token, additional features like staking and rewards will be added in the future.
 */
contract TimeLock is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

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

    IERC20Upgradeable public cRECY;

    uint256 public defaultLockPeriod;
    uint256 public earlyLockPeriod;
    uint256 public totalLocked;
    uint256 public totalUnlocked;
    uint256 public totalLockers;

    mapping(address => UserLock) private _userLocks;
    mapping(uint256 => address) private _lockersByIndex;

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

    error InLockPeriod(uint256 unlockTime);
    error AlreadyUnlocked();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _cRECY) external initializer {
        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();

        cRECY = IERC20Upgradeable(_cRECY);
        defaultLockPeriod = 2 * 365 days;
        earlyLockPeriod = 1 * 365 days;
    }

    /**
     * @notice Lock cRECY tokens for a period of time
     * @param amount token amount to lock
     */
    function lock(uint256 amount) external whenNotPaused nonReentrant {
        _registerLocker(_msgSender());

        _lock(_msgSender(), amount);
    }

    /**
     * @notice Unlock cRECY tokens
     * @param lockIndex index of the lock to unlock
     */
    function unlock(uint256 lockIndex) external whenNotPaused nonReentrant {
        _unlock(_msgSender(), lockIndex);
    }

    /**
     * @notice Pause the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Set early withdrawal allowed for a lock
     * @param user address of the user
     * @param index index of the lock
     * @param allowed true if early withdrawal is allowed
     */
    function setEarlyWithdrawal(
        address user,
        uint256 index,
        bool allowed
    ) external onlyOwner {
        _userLocks[user].locks[index].earlyWithdrawalAllowed = allowed;
    }

    /**
     * @notice Set lock periods
     * @param defaultLockPeriodInDays new default lock period in days
     * @param earlyLockPeriodInDays new early lock period in days
     */
    function setLockPeriods(
        uint256 defaultLockPeriodInDays,
        uint256 earlyLockPeriodInDays
    ) external onlyOwner {
        defaultLockPeriod = defaultLockPeriodInDays * 1 days;
        earlyLockPeriod = earlyLockPeriodInDays * 1 days;
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

    function _lock(address _user, uint256 _amount) private {
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

        emit Locked(_user, _amount, lockedAt, lockIndex);
    }

    function _unlock(address _user, uint256 _lockIndex) private {
        Lock memory userLock = _userLocks[_user].locks[_lockIndex];

        if (userLock.unlockedAt != 0) {
            revert AlreadyUnlocked();
        }

        uint256 unlockTime;
        if (userLock.earlyWithdrawalAllowed) {
            unlockTime = userLock.lockedAt + earlyLockPeriod;
        } else {
            unlockTime = userLock.lockedAt + defaultLockPeriod;
        }

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
}

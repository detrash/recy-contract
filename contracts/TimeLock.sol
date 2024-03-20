// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {CRecy} from "./CRecy.sol";

contract TimeLock is Pausable, Ownable, ReentrancyGuard {
    uint256 public lockPeriod = 2 * 365 days; // 2 years
    uint256 public emergencyLockPeriod = 365 days; // 1 year

    uint256 public minLockAmount = 100 * 10 ** 18; // 100 cRECY

    CRecy public immutable cRECY;

    struct Lock {
        address owner;
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
    uint256 private _totalLockers;
    uint256 private _totalLocked;
    uint256 private _totalUnlocked;

    event LockFunds(address indexed owner, uint256 amount, uint256 lockTime);
    event UnlockFunds(
        address indexed owner,
        uint256 amount,
        uint256 unlockTime
    );

    error InvalidLockAmount();
    error InvalidTime();
    error AlreadyUnlocked();

    constructor(address _cRECY) {
        cRECY = CRecy(_cRECY);
    }

    /**
     * @dev Lock cRECY token
     * @param amount amount to lock
     */
    function lock(uint256 amount) public whenNotPaused nonReentrant {
        if (amount < minLockAmount) {
            revert InvalidLockAmount();
        }

        uint256 lockTime = block.timestamp;
        uint256 lockIndexByUser = _lockCount[msg.sender];

        Lock memory _lock = Lock({
            owner: msg.sender,
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
    ) public whenNotPaused nonReentrant {
        if (_emergencyUnlock) {
            if (!_canEmergencyUnlock(msg.sender, _lockIndex)) {
                revert InvalidTime();
            }
            // TODO
        } else if (!_canUnlock(msg.sender, _lockIndex)) {
            revert InvalidTime();
        }

        _unlockUnChecked(msg.sender, _lockIndex);
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

    function _beforeLock(Lock memory _lock) internal {}

    function _afterLock(Lock memory _lock) internal {}

    function _onEmergencyUnlock(address _user, uint256 _lockIndex) internal {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

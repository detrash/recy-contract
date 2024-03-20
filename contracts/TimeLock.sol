// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLock is Pausable, Ownable {
    struct Lock {
        address owner;
        uint256 amount;
        uint256 releaseTime;
        uint256 lockTime;
    }

    event LockFunds(
        address indexed owner,
        uint256 amount,
        uint256 releaseTime,
        uint256 lockTime
    );
}

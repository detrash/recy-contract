import { time } from "@nomicfoundation/hardhat-network-helpers";
import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";

import { TimeLock } from "../typechain-types";

describe("TimeLock", function () {
  async function deployFixture() {
    const [owner, ali, bob] = await ethers.getSigners();

    const TimeLock__factory = await ethers.getContractFactory("TimeLock");
    const CRecy = await ethers.getContractFactory("CRecy");
    const FCWStatus__factory = await ethers.getContractFactory("FCWStatus");

    const cRECY = await CRecy.deploy(1000, 1000);
    await cRECY.transfer(ali.address, 200);
    await cRECY.transfer(bob.address, 200);

    const fcwStatus = await FCWStatus__factory.deploy();
    const timeLock = (await upgrades.deployProxy(TimeLock__factory, [
      await cRECY.getAddress(),
    ])) as unknown as TimeLock;

    return { cRECY, fcwStatus, timeLock, owner, ali, bob };
  }

  it("should deploy contracts", async () => {
    await deployFixture();
  });

  it("should lock token", async () => {
    const { cRECY, timeLock } = await deployFixture();
    const lockAmount = 100;

    await cRECY.approve(timeLock.getAddress(), lockAmount);
    await timeLock.lock(lockAmount);

    const lockedBalance = await cRECY.balanceOf(timeLock.getAddress());
    expect(lockedBalance).to.be.equal(lockAmount);
  });

  it("should revert if tries to unlock token in lock period", async () => {
    const { cRECY, timeLock, owner } = await deployFixture();
    const lockAmount = 100;
    await cRECY.approve(timeLock.getAddress(), lockAmount);
    await timeLock.lock(lockAmount);

    const events = await timeLock.queryFilter(timeLock.filters.Locked, -1);
    expect(events.length).to.be.equal(1);

    const lockEvent = events[0];
    const lockIndex = lockEvent.args.lockIndex;

    expect(lockIndex).to.be.equal(0);
    expect(lockEvent.args.amount).to.be.equal(lockAmount);

    const lastLock = await timeLock.getUserLastLock(owner.address);

    expect(lastLock.amount).to.be.equal(lockAmount);

    await expect(timeLock.unlock(lockIndex)).to.be.revertedWithCustomError(
      timeLock,
      "InLockPeriod"
    );
  });

  it("should unlock token after lock period", async () => {
    const { cRECY, timeLock, owner } = await deployFixture();

    const lockAmount = 100;
    await cRECY.approve(timeLock.getAddress(), lockAmount);
    await timeLock.lock(lockAmount);

    const events = await timeLock.queryFilter(timeLock.filters.Locked, -1);
    expect(events.length).to.be.equal(1);

    const lockEvent = events[0];
    const lockIndex = lockEvent.args.lockIndex;

    expect(lockIndex).to.be.equal(0);
    expect(lockEvent.args.amount).to.be.equal(lockAmount);

    const lastLock = await timeLock.getUserLastLock(owner.address);

    expect(lastLock.amount).to.be.equal(lockAmount);

    const defaultLockPeriod = await timeLock.defaultLockPeriod();

    await time.increase(defaultLockPeriod);

    await timeLock.unlock(lockIndex);

    const lockedBalance = await cRECY.balanceOf(timeLock.getAddress());
    expect(lockedBalance).to.be.equal(0);
  });

  it("should unlock token earlier upon admin allowance", async () => {
    const { cRECY, timeLock, owner, ali } = await deployFixture();

    const lockAmount = 100;
    await cRECY.connect(ali).approve(timeLock.getAddress(), lockAmount);
    await timeLock.connect(ali).lock(lockAmount);

    const events = await timeLock.queryFilter(timeLock.filters.Locked, -1);
    expect(events.length).to.be.equal(1);

    const lockEvent = events[0];
    const lockIndex = lockEvent.args.lockIndex;

    expect(lockIndex).to.be.equal(0);
    expect(lockEvent.args.amount).to.be.equal(lockAmount);

    const lastLock = await timeLock.getUserLastLock(ali.address);
    expect(lastLock.amount).to.be.equal(lockAmount);

    await expect(
      timeLock.connect(ali).unlock(lockIndex)
    ).to.be.revertedWithCustomError(timeLock, "InLockPeriod");

    // owner allows early withdrawal
    await timeLock.setEarlyWithdrawal(ali.address, lockIndex, true);

    const earlyLockPeriod = await timeLock.earlyLockPeriod();
    await time.increase(earlyLockPeriod);

    await timeLock.connect(ali).unlock(lockIndex);

    const lockedBalance = await cRECY.balanceOf(timeLock.getAddress());
    expect(lockedBalance).to.be.equal(0);
  });
});

import { SnapshotRestorer, takeSnapshot, time } from "@nomicfoundation/hardhat-network-helpers";
import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";
import crypto from "crypto";
import moment from "moment";
import { fromRpcSig, ecrecover, toBuffer, ECDSASignature } from 'ethereumjs-util';

import { CRecy, TimeLock } from "../typechain-types";
import { domainSeparator } from "./helpers/domainSeparator";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { TypedDataDomain, TypedDataField } from "ethers";

describe("TimeLock", function () {
  let timeLock: TimeLock
  let cRECY: CRecy
  let evmSig: ECDSASignature
  let typedMessage: {
    domain: TypedDataDomain,
    types: Record<string, TypedDataField[]>,
    message: Record<string, any>
  }
  let certificate: TimeLock.CertificateStruct
  let timeLockAddress: string
  let owner: HardhatEthersSigner, ali: HardhatEthersSigner, bob: HardhatEthersSigner
  let snapshot: SnapshotRestorer
  async function deployFixture() {
    [owner, ali, bob] = await ethers.getSigners();

    const TimeLock__factory = await ethers.getContractFactory("TimeLock");
    const CRecy = await ethers.getContractFactory("CRecy");
    const FCWStatus__factory = await ethers.getContractFactory("FCWStatus");

    cRECY = await CRecy.deploy(1000, 1000);
    await cRECY.transfer(ali.address, 200);
    await cRECY.transfer(bob.address, 200);

    const fcwStatus = await FCWStatus__factory.deploy();
    timeLock = (await upgrades.deployProxy(TimeLock__factory, [
      await cRECY.getAddress(),
    ])) as unknown as TimeLock;
    timeLockAddress = await timeLock.getAddress()

    return { cRECY, fcwStatus, timeLock, owner, ali, bob };
  }

  beforeEach( async () => {
    snapshot = await takeSnapshot()
    await deployFixture();
    typedMessage = {
      domain: {
        chainId: 31337,
        name: "GenericTypedMessage",
        version: "1",
        verifyingContract: await timeLock.getAddress()
      },
      message: {
        institution: ethers.encodeBytes32String("Acme Inc."),
        tons: '3',
        baseYear: '2024',
        baseMonth: '1',
        timespan: '12',
        signer: owner.address,
        authorization: `0x${crypto.randomBytes(32).toString('hex')}`,
        deadline: moment().add(1, 'day').format('X')
      },
      // primaryType: "Certificate",
      types: {
        Certificate: [
          { name: "institution", type: "bytes32" },
          { name: "tons", type: "uint8" },
          { name: "baseYear", type: "uint16" },
          { name: "baseMonth", type: "uint8" },
          { name: "timespan", type: "uint8" },
          { name: "signer", type: "address" },
          { name: "authorization", type: "bytes32" },
          { name: "deadline", type: "uint32" },
        ],
      },
    };

    const sig = await owner.signTypedData(
      typedMessage.domain,
      typedMessage.types,
      typedMessage.message
    )

    evmSig = fromRpcSig(sig);
    certificate = typedMessage.message as unknown as TimeLock.CertificateStruct

  });

  afterEach( () => {
    snapshot.restore()
  })

  it('should set the domain separator', async function () {
    const { chainId } = await ethers.provider.getNetwork()
    expect(
      await timeLock.DOMAIN_SEPARATOR(),
    ).to.equal(
      await domainSeparator('GenericTypedMessage', '1', chainId, timeLockAddress),
    );
  })

  it("should lock token", async () => {
    const lockAmount = 100;

    await cRECY.connect(ali).approve(timeLock.getAddress(), lockAmount);
    await timeLock.connect(ali).lock(lockAmount, certificate, evmSig);

    const lockedBalance = await cRECY.balanceOf(timeLock.getAddress());
    expect(lockedBalance).to.be.equal(lockAmount);
  });

  it("should revert if tries to unlock token in lock period", async () => {
    const lockAmount = 100;
    await cRECY.approve(timeLock.getAddress(), lockAmount);
    await timeLock.lock(lockAmount, certificate, evmSig);

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

  it('Should revert if locking or unlocking when contract paused', async () => {
    const lockAmount = 100;
    await cRECY.approve(timeLock.getAddress(), lockAmount);

    await timeLock.pause()
    await expect(timeLock.lock(lockAmount, certificate, evmSig)).to.be.revertedWith('Pausable: paused');
  })

  it("should unlock token after lock period", async () => {
    const lockAmount = 100;
    await cRECY.approve(timeLock.getAddress(), lockAmount);
    await timeLock.lock(lockAmount, certificate, evmSig);

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
    const lockAmount = 100;
    await cRECY.connect(ali).approve(timeLock.getAddress(), lockAmount);
    await timeLock.connect(ali).lock(lockAmount, certificate, evmSig);

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

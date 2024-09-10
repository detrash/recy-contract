import { SnapshotRestorer, takeSnapshot, time } from "@nomicfoundation/hardhat-network-helpers";
import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";
import crypto from "crypto";
import moment from "moment";
import { fromRpcSig, ecrecover, toBuffer, ECDSASignature } from 'ethereumjs-util';

import { CRecy, TimeLock, RecyCertificate } from "../typechain-types";
import { domainSeparator } from "./helpers/domainSeparator";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { TypedDataDomain, TypedDataField } from "ethers";

describe("TimeLock", function () {
  let timeLock: TimeLock
  let cRECY: CRecy
  let recyCertificate: RecyCertificate
  let evmSigCert: ECDSASignature
  let evmSigUnlockAuth: ECDSASignature
  let certTypedMessage: {
    domain: TypedDataDomain,
    types: Record<string, TypedDataField[]>,
    message: Record<string, any>
  }
  let unlockAuthTypedMessage: {
    domain: TypedDataDomain,
    types: Record<string, TypedDataField[]>,
    message: Record<string, any>
  }
  let certificate: TimeLock.CertificateAuthorizationStruct
  let unlockAuth: TimeLock.UnlockAuthorizationStruct
  let timeLockAddress: string
  let owner: HardhatEthersSigner, ali: HardhatEthersSigner, bob: HardhatEthersSigner
  let snapshot: SnapshotRestorer
  async function deployFixture() {
    [owner, ali, bob] = await ethers.getSigners();

    const TimeLock__factory = await ethers.getContractFactory("TimeLock");
    const CRecy = await ethers.getContractFactory("CRecy");
    const RecyCertificate = await ethers.getContractFactory("RecyCertificate")
    const FCWStatus__factory = await ethers.getContractFactory("FCWStatus");

    cRECY = await CRecy.deploy(1000, 1000);
    await cRECY.transfer(ali.address, 200);
    await cRECY.transfer(bob.address, 200);


    const fcwStatus = await FCWStatus__factory.deploy();
    recyCertificate = await RecyCertificate.deploy()
    timeLock = (await upgrades.deployProxy(TimeLock__factory, [
      await cRECY.getAddress(), await recyCertificate.getAddress()
    ])) as unknown as TimeLock;
    
    await recyCertificate.initialize()
    const MINTER_ROLE = ethers.keccak256(Buffer.from('MINTER_ROLE'))
    const DEFAULT_ADMIN_ROLE = ethers.keccak256(Buffer.from('DEFAULT_ADMIN_ROLE'))
    const BURNER_ROLE = ethers.keccak256(Buffer.from('BURNER_ROLE'))
    const OPERATOR_ROLE = ethers.keccak256(Buffer.from('OPERATOR_ROLE'))
    
    timeLockAddress = await timeLock.getAddress()
    await recyCertificate.grantRole(MINTER_ROLE, timeLockAddress)
    await recyCertificate.grantRole(OPERATOR_ROLE, timeLockAddress)

    await timeLock.setupTraits()
    return { cRECY, fcwStatus, timeLock, owner, ali, bob };
  }

  beforeEach( async () => {
    snapshot = await takeSnapshot()
    await deployFixture();
    const domain = {
      chainId: 31337,
      name: "GenericTypedMessage",
      version: "1",
      verifyingContract: await timeLock.getAddress()
    }
    certTypedMessage = {
      domain,
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
      types: {
        CertificateAuthorization: [
          { name: "institution", type: "bytes32" },
          { name: "tons", type: "uint8" },
          { name: "baseYear", type: "uint16" },
          { name: "baseMonth", type: "uint8" },
          { name: "timespan", type: "uint8" },
          { name: "signer", type: "address" },
          { name: "authorization", type: "bytes32" },
          { name: "deadline", type: "uint256" },
        ],
      },
    };
    unlockAuthTypedMessage = {
      domain,
      message: {
        lockAccount: ali.address,
        signer: owner.address,
        authorization: `0x${crypto.randomBytes(32).toString('hex')}`,
        deadline: moment().add(1, 'day').format('X')
      },
      types: {
        UnlockAuthorization: [
          { name: "lockAccount", type: "address" },
          { name: "signer", type: "address" },
          { name: "authorization", type: "bytes32" },
          { name: "deadline", type: "uint32" },
        ]
      }
    }

    const sigCert = await owner.signTypedData(
      certTypedMessage.domain,
      certTypedMessage.types,
      certTypedMessage.message
    )

    const sigUnlockAuth = await owner.signTypedData(
      unlockAuthTypedMessage.domain,
      unlockAuthTypedMessage.types,
      unlockAuthTypedMessage.message
    )

    evmSigCert = fromRpcSig(sigCert);
    evmSigUnlockAuth = fromRpcSig(sigUnlockAuth);

    certificate = certTypedMessage.message as unknown as TimeLock.CertificateAuthorizationStruct
    unlockAuth = unlockAuthTypedMessage.message as unknown as TimeLock.UnlockAuthorizationStruct

  });

  afterEach( () => {
    snapshot.restore()
  })

  describe('General', () => {
    it('should set the domain separator', async function () {
      const { chainId } = await ethers.provider.getNetwork()
      expect(
        await timeLock.DOMAIN_SEPARATOR(),
      ).to.equal(
        await domainSeparator('GenericTypedMessage', '1', chainId, timeLockAddress),
      );
    })
  })

  describe('Lock operations', () => {
    it('Should revert if locking when contract paused', async () => {
      const lockAmount = 100;
      await cRECY.approve(timeLock.getAddress(), lockAmount);
  
      await timeLock.pause()
      await expect(timeLock.lock(lockAmount, certificate, evmSigCert)).to.be.revertedWith('Pausable: paused');
    })

    it("should lock token", async () => {
      const lockAmount = 100;
  
      await cRECY.connect(ali).approve(timeLock.getAddress(), lockAmount);
      await timeLock.connect(ali).lock(lockAmount, certificate, evmSigCert);
  
      const lockedBalance = await cRECY.balanceOf(timeLock.getAddress());
      expect(lockedBalance).to.be.equal(lockAmount);

      const status = await recyCertificate.getAttribute("1", "status")
      expect(status).to.be.equal("ACTIVE")
    });
  })

  describe('Unlock operations', () => {
    beforeEach(async () => {
      snapshot = await takeSnapshot()
    })
    afterEach( () => {
      snapshot.restore()
    })
    it("should revert if tries to unlock token during lock period", async () => {
      const lockAmount = 100;
      await cRECY.approve(timeLock.getAddress(), lockAmount);
      await timeLock.lock(lockAmount, certificate, evmSigCert);
  
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
      const lockAmount = 100;
      await cRECY.approve(timeLock.getAddress(), lockAmount);
      await timeLock.lock(lockAmount, certificate, evmSigCert);
  
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

      const status = await recyCertificate.getAttribute("1", "status")
      expect(status).to.be.equal("COMPLETE")
    });
  
  })
});

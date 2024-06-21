import { ethers, upgrades } from "hardhat";

import { TimeLock } from "../typechain-types";
import { expect } from "chai";

describe("TimeLock", function () {
  async function deployFixture() {
    const TimeLock__factory = await ethers.getContractFactory("TimeLock");
    const CRecy = await ethers.getContractFactory("CRecy");
    const FCWERC721__factory = await ethers.getContractFactory("FCWERC721");

    const cRECY = await CRecy.deploy(1000, 1000);

    const deTrashCertificate = await FCWERC721__factory.deploy();
    const timeLock = (await upgrades.deployProxy(TimeLock__factory, [
      cRECY.address,
    ])) as TimeLock;

    return { cRECY, deTrashCertificate, timeLock };
  }

  it("should deploy contracts", async () => {
    await deployFixture();
  });

  it("should lock token", async () => {
    const { cRECY, timeLock } = await deployFixture();

    await cRECY.approve(timeLock.address, 500);
    await timeLock.lock(500);
  });

  it("should unlock token", async () => {
    const { cRECY, timeLock } = await deployFixture();

    await cRECY.approve(timeLock.address, 500);
    await timeLock.lock(500);

    // TODO
    // await expect(timeLock.unlock(500)).to.be.revertedWith(`AlreadyListed`);
  });
});

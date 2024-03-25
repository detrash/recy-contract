import { ethers } from "hardhat";

describe("TimeLock", function () {
  async function deployFixture() {
    const TimeLock = await ethers.getContractFactory("TimeLock");
    const CRecy = await ethers.getContractFactory("CRecy");
    const DeTrashCertificate = await ethers.getContractFactory(
      "DeTrashCertificate"
    );

    const cRECY = await CRecy.deploy(1000, 1000);
    const deTrashCertificate = await DeTrashCertificate.deploy();
    const timeLock = await TimeLock.deploy(
      cRECY.address,
      deTrashCertificate.address
    );

    return { cRECY, deTrashCertificate, timeLock };
  }
});

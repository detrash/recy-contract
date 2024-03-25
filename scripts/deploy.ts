import { Contract } from "ethers";
import hre, { ethers, upgrades } from "hardhat";

async function deployAndVerify({
  name,
  args,
  isProxy,
}: {
  name: string;
  args: any[];
  isProxy: boolean;
}) {
  let contract: Contract;
  if (isProxy) {
    const ContractFactory = await ethers.getContractFactory(name);
    contract = await upgrades.deployProxy(ContractFactory, args);
  } else {
    contract = await ethers.deployContract(name, args);
  }

  console.log(`${name} contract is deployed to ${contract.target}`);

  // npx hardhat verify [CONTRACT_ADDRESS] [...CONSTRUCTOR_ARGS] --network alfajores
  if (contract.deploymentTransaction()?.hash) {
    await contract.deploymentTransaction()?.wait(5);
    await hre.run("verify:verify", {
      address: contract.target,
      constructorArguments: args,
    });
  }
}
async function main() {
  const contracts = [
    {
      name: "CRecyTest",
      args: [],
      isProxy: false,
    },
    {
      name: "TimeLock",
      args: ["0xf64C1a07144B22cdD109d5b82004aEd4759114c4"],
      isProxy: true,
    },
  ];

  for (const contract of contracts) {
    await deployAndVerify(contract);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { Contract } from "ethers";
import hre, { ethers, upgrades } from "hardhat";

export async function deploy({
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

  console.log(`${name} contract is deployed to ${await contract.getAddress()}`);

  return contract;
}

export async function deployAndVerify({
  name,
  args,
  isProxy,
}: {
  name: string;
  args: any[];
  isProxy: boolean;
}) {
  const contract = await deploy({ name, args, isProxy });

  // npx hardhat verify [CONTRACT_ADDRESS] [...CONSTRUCTOR_ARGS] --network alfajores
  if (contract.deploymentTransaction()?.hash) {
    await contract.deploymentTransaction()?.wait(5);
    await hre.run("verify:verify", {
      address: contract.target,
      constructorArguments: args,
    });
  }
}

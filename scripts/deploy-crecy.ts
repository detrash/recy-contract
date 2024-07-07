import { deploy } from "./utils";

async function main() {
  const contracts = [
    {
      name: "CRecy",
      args: [1000, 1000],
      isProxy: false,
    },
  ];

  for (const contract of contracts) {
    await deploy(contract);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

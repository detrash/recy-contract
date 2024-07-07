import { deploy } from "./utils";

async function main() {
  const contracts = [
    {
      name: "TimeLock",
      args: ["0xf64C1a07144B22cdD109d5b82004aEd4759114c4"],
      isProxy: true,
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

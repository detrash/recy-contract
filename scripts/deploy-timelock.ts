import { deploy } from "./utils";

async function main() {
  const contracts = [
    {
      name: "TimeLock",
      args: ["0x004c368A3fb45b0CD601e2203Fd2948D9d695a3b"],
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

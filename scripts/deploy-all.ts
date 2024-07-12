import { deploy } from "./utils";

async function main() {
  const contracts = [
    {
      name: "CRecy",
      args: [1000, 1000] as any[],
      isProxy: false,
    },
    {
      name: "FCWStatus",
      args: [],
      isProxy: false,
    },
    {
      name: "TimeLock",
      args: [],
      isProxy: true,
    },
  ];

  for (const c of contracts) {
    const contrat = await deploy(c);

    if (c.name === "CRecy") {
      contracts[2].args = [await contrat.getAddress()];
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

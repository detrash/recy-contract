import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// TODO
export default buildModule("CRecy", (m) => {
  const apollo = m.contract("CRecy", [
    m.getParameter("cap"),
    m.getParameter("initialSupply"),
  ]);

  return { apollo };
});

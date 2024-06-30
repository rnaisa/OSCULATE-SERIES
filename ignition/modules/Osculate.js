const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");


module.exports = buildModule("OsculateModule", (m) => {

  const osculate = m.contract("Osculate");

  return { osculate };
});
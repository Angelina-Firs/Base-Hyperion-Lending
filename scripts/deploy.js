const hre = require("hardhat");
async function main() {
  const LendingPool = await hre.ethers.getContractFactory("HyperionLendingPool");
  const pool = await LendingPool.deploy();
  await pool.deployed();
  console.log("-> Hyperion Lending Pool active at:", pool.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

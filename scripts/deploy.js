async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const lpStaking = await ethers.deployContract("LPStaking");
  const treasury =  await ethers.deployContract("Treasury");

  console.log("LP Staking Contract address:", await lpStaking.getAddress());
  console.log("Treasury Contract address:", await treasury.getAddress());

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
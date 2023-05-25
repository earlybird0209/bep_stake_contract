async function main() {
  const [deployer] = await ethers.getSigners();
  const dev = deployer.getAddress();

  const Token = await ethers.getContractFactory("MyToken");
  const token = await Token.deploy();
  await token.deployed();

  const Token2 = await ethers.getContractFactory("MyToken");
  const token2 = await Token2.deploy();
  await token2.deployed();

  const USDT = await ethers.getContractFactory("USDT");
  const USDTtoken = await USDT.deploy();
  await USDTtoken.deployed();

  const Staking = await ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(
    token.address,
    token2.address,
    USDTtoken.address
  );
  await staking.deployed();

  await staking.changeNFTcontract(token.address);
  await token2.safeMint(dev); //mint 1 NFT
  await USDTtoken.approve(staking.address, toBN(1000000, 18));
  await staking.initialize();
  await staking.deposit(toBN(2000, 18));
}
function toBN(number, decimal) {
  return (number * 10 ** decimal).toLocaleString("fullwide", {
    useGrouping: false,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

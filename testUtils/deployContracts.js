
function toBN(number, decimal) {
  return (number * 10 ** decimal).toLocaleString("fullwide", {
    useGrouping: false,
  });
}

module.exports = async function () {
  // ethers is avaialble in the global scope
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const Token = await ethers.getContractFactory("MyToken");
  const USDT = await ethers.getContractFactory("BEP20USDT");
  const Staking = await ethers.getContractFactory("StakingTest");
  global.USDTContract = USDT.attach('0x5dCD3cdaD224b794Cd2516762A64731EE5c2e2bA');
  global.NFTtokenContract = Token.attach('0xE12ae70329C83C23526C0D393B5Fe5eB58396B52');
  global.NFTtokenContract2 = Token.attach('0xae4DDb3e87B51Eca1fcDdf975aF12d1E04c4EEdB');
  global.NFTtokenContract3 = Token.attach('0x3FfCdbAf15FB13626f33Fd2b311EB71db53468c2');
    // global.USDTContract = await USDT.deploy();

    // global.NFTtokenContract = await Token.deploy(global.USDTContract.address);
    // global.NFTtokenContract2 = await Token.deploy(global.USDTContract.address);
    // global.NFTtokenContract3 = await Token.deploy(global.USDTContract.address);
  //   global.stakingContract = await Staking.deploy(
  //     global.NFTtokenContract.address,
  //     global.NFTtokenContract2.address,
  //     global.USDTContract.address
  // );
  global.stakingContract = await Staking.deploy(
    global.NFTtokenContract.address,
    global.NFTtokenContract2.address,
    global.NFTtokenContract3.address,
    global.USDTContract.address
);
  console.log('deployed');
  // console.log(global.NFTtokenContract.address);
  // console.log(global.NFTtokenContract2.address);
  // console.log(global.NFTtokenContract3.address);
  console.log(global.stakingContract.address);

  const [
    owner,
    wallet1
  ] = await ethers.getSigners();

  // await stakingContract.changeNFTcontract(
  //   NFTtokenContract.address,
  //   NFTtokenContract2.address
  // );
  // console.log('approve start');

  // await USDTContract.approve(stakingContract.address, toBN(10000000, 18));
  // await USDTContract.approve('0x75a793df4b746163981caDB427f17A64af86C7F7', toBN(10000000, 18));

  // // await USDTContract.connect(wallet1).approve(
  // //   stakingContract.address,
  // //   toBN(10000000, 18)
  // // );
  // console.log('approve second');
  
  // await USDTContract.transfer(owner.address, toBN(20000000, 18));
  // await USDTContract.transfer('0x75a793df4b746163981caDB427f17A64af86C7F7', toBN(1000000, 18))
  // await USDTContract.transfer(stakingContract.address, toBN(200000, 18));
 
  // //await USDTContract.approve(NFTtokenContract.address, toBN(10000, 18));

  // await USDTContract.transfer(wallet1.address, toBN(200000, 18));
  
  // await USDTContract.connect(wallet1).approve(
  //   NFTtokenContract.address,
  //   toBN(10000, 18)
  // );

  // await NFTtokenContract.connect(wallet1).safeMint();

  // await USDTContract.connect(wallet1).approve(
  //   NFTtokenContract2.address,
  //   toBN(10000, 18)
  // );

  // await NFTtokenContract2.connect(wallet1).safeMint();
  // await stakingContract.initialize();
  
  // await NFTtokenContract.safeMint();

  global.owner = owner;
  global.wallet1 = wallet1;
  global.zeroAddress = "0x0000000000000000000000000000000000000000";
};

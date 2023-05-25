const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const deployContracts = require("../testUtils/deployContracts");

function toBN(number, decimal) {
  return (number * 10 ** decimal).toLocaleString("fullwide", {
    useGrouping: false,
  });
}

var oneday = 86400;

var depositamount = 1000;
var DROP_RATE = 60;
var DEPOSIT_FEE = 0;
var WITHDRAW_FEE = 0;
var Increase7days = 7;
var Increase27days = 27;
var Increase29days = 29;
var SecondDepositAmount = 60000;
var depositamount3 = 10000;

describe("Staking contract", function () {
  before(async () => {
    await deployContracts();
    console.log("deploy done");
    DROP_RATE = await stakingContract.DROP_RATE();
    DEPOSIT_FEE = await stakingContract.depositFeeBP();
    WITHDRAW_FEE = await stakingContract.withdrawFeeBP();
    console.log("drop rate: ", DROP_RATE);
    console.log("deposit fee", DEPOSIT_FEE);
    console.log("withdraw fee", WITHDRAW_FEE);
  });

  /*
  it("Shouldn't deposit without NFT", async function () {
    await expect(
      stakingContract.deposit(toBN(depositamount, 18))
    ).to.be.revertedWith("User doesn't own NFT");
  });
*/
  it("Should deposit correctly", async function () {
    //because today is monday
    await increaseTimeBy(11 * oneday);

    await stakingContract.connect(wallet1).deposit(toBN(depositamount, 18));
    await stakingContract.connect(wallet1).deposit(toBN(SecondDepositAmount, 18));
    await stakingContract.connect(wallet1).deposit(toBN(depositamount3, 18));
    var mydeposits = (await stakingContract.userInfo(wallet1.address))
      .NoOfDeposits;

    expect(mydeposits).to.equal(3);

    var useri = await stakingContract.memberDeposit(wallet1.address, 0);

    expect(Number(useri.amount)).to.equal(
      (1 - DEPOSIT_FEE / 10000) * depositamount * 10 ** 18
    );

    var useri1 = await stakingContract.memberDeposit(wallet1.address, 1);

    expect(Number(useri1.amount)).to.equal(
      (1 - DEPOSIT_FEE / 10000) * SecondDepositAmount * 10 ** 18
    );
  });

  it("Should update withdraw wallet correctly", async function () {

    await expect(stakingContract.connect(wallet1).changeWithdrawalAddress(owner.address)).not.to
      .be.reverted;
    expect(
      (await stakingContract.userInfo(wallet1.address)).WithdrawAddress
    ).to.equal(owner.address);
    
  });

  it("Should update fee wallets correctly", async function () {
    await expect(stakingContract.ChangefeeAddress(wallet1.address)).not.to.be
      .reverted;
    expect(await stakingContract.feeWallet()).to.equal(wallet1.address);
    await expect(stakingContract.ChangefeeAddress(owner.address)).not.to.be
      .reverted;
    expect(await stakingContract.feeWallet()).to.equal(owner.address);
  });

  it("Should succesfully change NFT address", async function () {
    await stakingContract.changeNFTcontract(
      global.NFTtokenContract.address,
      global.NFTtokenContract2.address
    );

    await stakingContract.changeNFTcontract(
      global.NFTtokenContract.address,
      global.NFTtokenContract2.address
    );
  });

  it("can initiate Claim after 42 days", async function () {
    await increaseTimeBy(42 * oneday);

    await expect(stakingContract.connect(wallet1).InitiateClaim()).not.to.be.reverted;

  });
  it("Claim after 49 days", async function () {
    await increaseTimeBy(7 * oneday);

    const pendingClaim = await stakingContract.connect(wallet1).pendingClaims(wallet1.address);
    expect((1 * pendingClaim / 10 ** 18).toFixed(0)).to.equal(
      ((49 - 28) * (depositamount + SecondDepositAmount + depositamount3) *
      (1 - DEPOSIT_FEE / 10000) *
      DROP_RATE / 10000
      ).toFixed(0)
    );
    await expect(stakingContract.connect(wallet1).Claim()).not.to.be.reverted;

    const pendingClaim1 = await stakingContract.connect(wallet1).pendingClaims(wallet1.address);
    expect((1 * pendingClaim1 / 10 ** 18).toFixed(0)).to.equal(
      (0).toFixed(0)
    );

  });

  it("Should compound after 56 days", async function () {
    await increaseTimeBy(7 * oneday);
    
    await expect(stakingContract.connect(wallet1).Compound()).not.to.be.reverted;

    dep1 = await stakingContract.connect(wallet1).memberDeposit(wallet1.address, 3);
    //    console.log(dep1);
    expect((dep1.amount / 10 ** 18).toFixed(0)).to.equal(
      ((depositamount + SecondDepositAmount + depositamount3)  * (1 - DEPOSIT_FEE / 10000) *
      (1 - WITHDRAW_FEE / 10000) *
      7 * DROP_RATE / 10000)
      .toFixed(0)
    );
  });


  it("Can choose relock deposit after day 56", async function () {
    await expect(stakingContract.connect(wallet1).UnlockDeposit(2, 1)).not.to.be.reverted;
    dep1 = await stakingContract.connect(wallet1).memberDeposit(wallet1.address, 2);

    expect(dep1.currentState).to.equal(1);
  });

  it("Can initiate withdraw deposit after 56 days", async function () {
    await expect(stakingContract.connect(wallet1).InitiateWithdrawal(1)).not.to.be.reverted;

  });

  it("Can withdraw deposit after 63 days", async function () {
    await increaseTimeBy(7 * oneday);
    const res = await stakingContract.connect(wallet1).Withdraw(1);

    dep1 = await stakingContract.connect(wallet1).memberDeposit(wallet1.address, 1);
//    console.log(dep1);
    expect((dep1.amount / 10 ** 18).toFixed(0)).to.equal(
      (SecondDepositAmount * (1 - DEPOSIT_FEE / 10000) - 50000)
      .toFixed(0)
    );

  });

  



});
function getres(numb) {
  if (numb > 27) {
    return numb - 28;
  } else if (numb > 13) {
    return numb - 14;
  } else {
    return numb;
  }
}
async function increaseTimeBy(amount) {
  var blockNumBefore = await ethers.provider.getBlockNumber();
  var blockBefore = await ethers.provider.getBlock(blockNumBefore);
  await time.increaseTo(blockBefore.timestamp + amount);
}
async function decreaseTimeBy(amount) {
  var blockNumBefore = await ethers.provider.getBlockNumber();
  var blockBefore = await ethers.provider.getBlock(blockNumBefore);
  await time.increaseTo(blockBefore.timestamp - amount);
  var timestampBefore = blockBefore.timestamp;
  var date = new Date(timestampBefore * 1000);
  // console.log(`time now after increase is ${date}`);
}
async function currentTimeis() {
  var blockNumBefore = await ethers.provider.getBlockNumber();
  var blockBefore = await ethers.provider.getBlock(blockNumBefore);
  var timestampBefore = blockBefore.timestamp;
  var date = new Date(timestampBefore * 1000);
  console.log(`Current time now is ${date}`);
  return date;
}

async function currentTimeisfromTimestamp(ts) {
  var date = new Date(ts * 1000);
  // console.log(date);
  return date;
}
async function getPending(dep, user) {
  var pending = await stakingContract.connect(wallet1).pendingReward(dep, user);
  return pending / 10 ** 18;
}

async function currentUserInfo() {
  var info = await stakingContract.userInfo(owner.address);

  console.log(info);
}
async function currentDifferenceFromActionDay() {
  var blockNumBefore = await ethers.provider.getBlockNumber();
  var blockBefore = await ethers.provider.getBlock(blockNumBefore);
  var timestampBefore = blockBefore.timestamp;
  var wk = await stakingContract.getWeek();

  var info = await stakingContract.getDifferenceFromActionDay();

  // console.log(timestampBefore, ts, ts / 86400, wk, ad, info);
}

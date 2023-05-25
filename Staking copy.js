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
    increaseTimeBy(4 * oneday + 1);
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
    await stakingContract.connect(wallet1).deposit(toBN(depositamount, 18));
    await stakingContract.connect(wallet1).deposit(toBN(SecondDepositAmount, 18));
    var mydeposits = (await stakingContract.userInfo(wallet1.address))
      .NoOfDeposits;

    expect(mydeposits).to.equal(2);

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

  it("Pending Rewards 0 for first 28 days and correct after 28 ", async function () {
    await expect(stakingContract.UnlockDeposit(0, 1)).revertedWith(
      "first deposit cannot be decided"
    );

    await increaseTimeBy(28 * oneday);
    await increaseTimeBy(28 * oneday);

    pendingRewards = (await getPending(1, wallet1.address)).toFixed(0);
    expect((1 * pendingRewards).toFixed(0)).to.equal(
      (
        ((SecondDepositAmount * DROP_RATE * 28) / 10000) *
        (1 - DEPOSIT_FEE / 10000)
      ).toFixed(0)
    );

  });

  it("Can choose unlock deposit after day 56", async function () {
    //56day
    await expect(stakingContract.connect(wallet1).UnlockDeposit(1, 1)).not.to.be.reverted;
    useri = await stakingContract.memberDeposit(wallet1.address, 1);

    expect(useri.currentState).to.equal(1);
  });

  it("Can choose withdraw deposit after 56 days", async function () {
    await expect(stakingContract.connect(wallet1).InitiateWithdrawal(1)).not.to.be.reverted;
    useri = await stakingContract.memberDeposit(owner.address, 1);
    expect(Number(useri.amount)).to.equal(
      (1 - DEPOSIT_FEE / 10000) * SecondDepositAmount * 10 ** 18
    );
    expect(useri.unlocked).to.equal(2);
  });

  it("can Claim after 70 days", async function () {
    await increaseTimeBy(9 * oneday);

    await stakingContract.connect(wallet1).deposit(toBN(depositamount, 18));
  });

  it("Should Initiate Claim correctly ", async function () {
    await increaseTimeBy(3 * oneday);

    await expect(stakingContract.InitiateClaim()).not.to.be.reverted;
    var userInfo = await stakingContract.userInfo(owner.address);

    expect(userInfo.ClaimInitiated).to.equal(true);
    useri = await stakingContract.memberDeposit(owner.address, 1);

    var pendingRewards = (await getPending(0, owner.address)).toFixed(0);
    expect((1 * pendingRewards).toFixed(0)).to.equal(
      (
        depositamount *
        0.95 *
        ((DROP_RATE * 7) / 10000) *
        (1 - DEPOSIT_FEE / 10000)
      ).toFixed(0)
    );
  });

  it("Should fail to initiateUnlock same week", async function () {
    await expect(stakingContract.Withdraw(0)).revertedWith("Only after 7d");
  });

  it("Should Claim day 118 after deposit, without compounds, correct pending amount", async function () {
    await increaseTimeBy(Increase7days * oneday);

    var TMDBC = (await USDTContract.balanceOf(owner.address)) / 10 ** 18;
    pendingbefore = await getPending(0, owner.address);
    var pendingbefore2 = await getPending(1, owner.address);

    await expect(stakingContract.Claim()).not.to.be.reverted;

    var TMDAC = (await USDTContract.balanceOf(owner.address)) / 10 ** 18;

    var pendingafter = await getPending(0, owner.address);
    var pendingafter2 = await getPending(1, owner.address);
    expect((1 * pendingbefore + pendingbefore2).toFixed(0)).to.equal(
      (0.95 * (TMDAC - TMDBC)).toFixed(0)
    );
    expect(pendingafter).to.equal(0);
    expect(pendingafter2).to.equal(0);
  });

  it("Compound increase deposits correctly", async function () {
    await increaseTimeBy(1 * oneday);

    await expect(stakingContract.InitiateClaim()).revertedWith(
      "wrong Initiate day"
    );
    await increaseTimeBy(6 * oneday);

    await stakingContract.connect(wallet1).deposit(toBN(depositamount, 18));
    await stakingContract.connect(wallet2).deposit(toBN(depositamount, 18));
    var depInfo = await stakingContract.memberDeposit(owner.address, 1);

    await expect(stakingContract.InitiateWithdrawal(1)).revertedWith(
      "Withdraw already initialised"
    );

    var depInfo = await stakingContract.memberDeposit(owner.address, 1);
    var userInfo = await stakingContract.userInfo(owner.address);
    expect(userInfo.ClaimInitiated).to.equal(false);

    await increaseTimeBy(77 * oneday);
    await expect(stakingContract.Withdraw(1)).not.to.be.reverted;

    mydeposits = (await stakingContract.userInfo(owner.address)).NoOfDeposits;

    await increaseTimeBy(7 * oneday);

    var depInfo = await stakingContract.memberDeposit(owner.address, 1);
    var userInfo = await stakingContract.userInfo(owner.address);
    expect(userInfo.ClaimInitiated).to.equal(false);
    expect(depInfo.WithdrawInitiated).to.equal(0);
    await increaseTimeBy(7 * oneday);

    expect(mydeposits).to.equal(3);
  });

  it("Should Claim day 118 after deposit, with compounds, correct pending amount", async function () {
    await expect(stakingContract.Withdraw(1)).to.be.revertedWith(
      "Withdraw not initiated"
    );

    await stakingContract.connect(wallet1).deposit(toBN(depositamount, 18));
    await stakingContract.connect(wallet2).deposit(toBN(depositamount, 18));
    await stakingContract.deposit(toBN(depositamount, 18));
    await stakingContract.deposit(toBN(depositamount, 18));
    mydeposits = (await stakingContract.userInfo(owner.address)).NoOfDeposits;
    expect(mydeposits).to.equal(5);
    await increaseTimeBy(7 * oneday);
    await increaseTimeBy(70 * oneday);

    await expect(stakingContract.UnlockDeposit(3, 1)).not.to.be.reverted;
    await expect(stakingContract.InitiateClaim()).not.to.be.reverted;

    var depInfo = await stakingContract.memberDeposit(owner.address, 3);
    var userInfo = await stakingContract.userInfo(owner.address);
    expect(userInfo.ClaimInitiated).to.equal(true);
    expect(depInfo.WithdrawInitiated).to.equal(0);

    await increaseTimeBy(7 * oneday);

    mydeposits = (await stakingContract.userInfo(owner.address)).NoOfDeposits;

    expect(mydeposits).to.equal(5);
    await increaseTimeBy(7 * oneday);

    await expect(stakingContract.InitiateClaim()).not.to.be.reverted;

    var depInfo = await stakingContract.memberDeposit(owner.address, 3);
    var userInfo = await stakingContract.userInfo(owner.address);
    expect(userInfo.ClaimInitiated).to.equal(true);
    expect(depInfo.WithdrawInitiated).to.equal(0);
    await increaseTimeBy(7 * oneday);
    var TMDBC = (await USDTContract.balanceOf(owner.address)) / 10 ** 18;
    pendingbefore = await stakingContract.getAllPendingRewards();

    await expect(stakingContract.Claim()).not.to.be.reverted;
    var TMDAC = (await USDTContract.balanceOf(owner.address)) / 10 ** 18;

    var pendingafter = await stakingContract.getAllPendingRewards();
    expect(((1 * pendingbefore) / 10 ** 18 / 0.95).toFixed(0)).to.equal(
      (TMDAC - TMDBC).toFixed(0)
    );
    expect(pendingafter).to.equal(0);
  });

  it("Shouldn't be able to Initiateclaim/InitiateAction(0) after 1 week of initiateUnlock", async function () {
    await expect(stakingContract.InitiateClaim()).revertedWith(
      "wrong Initiate day"
    );
    await expect(stakingContract.InitiateClaim()).revertedWith(
      "wrong Initiate day"
    );
  });

  it("Should be able withdraw all funds", async function () {
    var allbal = await USDTContract.balanceOf(stakingContract.address);
    var allbalowner = await USDTContract.balanceOf(
      await stakingContract.feeWallet()
    );

    await expect(stakingContract.getAmount(allbal)).not.to.be.reverted;
    var allbalownerafter = await USDTContract.balanceOf(
      await stakingContract.feeWallet()
    );
    expect(((1 * allbal) / 10 ** 18).toFixed(0)).to.equal(
      ((allbalownerafter - allbalowner) / 10 ** 18).toFixed(0)
    );
    allbal = await USDTContract.balanceOf(stakingContract.address);
    expect(allbal).to.equal(0);
  });

  it("Should be able to deposit after withdrawing all funds", async function () {
    await stakingContract.deposit(toBN(depositamount3, 18));
    await increaseTimeBy(60 * oneday);
    //await expect(stakingContract.UnlockDeposit(2, 1)).not.to.be.reverted;
    // await expect(stakingContract.UnlockDeposit(3, 1)).not.to.be.reverted;
    await expect(stakingContract.UnlockDeposit(4, 1)).not.to.be.reverted;

    await increaseTimeBy(20 * oneday);

    // var pendingRewards = (await getPending(4)).toFixed(0);
    var usertotalDe = (await stakingContract.userInfo(owner.address))
      .NoOfDeposits;

    var totalDepLeft = 0;

    for (let i = 0; i < usertotalDe; i++) {
      if (
        (await stakingContract.memberDeposit(owner.address, Number(i)))
          .unlocked == 1
      ) {
        totalDepLeft +=
          (await stakingContract.memberDeposit(owner.address, Number(i)))
            .amount /
          10 ** 18;

        //    console.log(i);
      }
    }

    await increaseTimeBy(11 * oneday);
    //

    await expect(stakingContract.InitiateWithdrawal(4)).not.to.be.reverted;
    await increaseTimeBy(55 * oneday);

    var mydepositsBefore = (await stakingContract.userInfo(owner.address))
      .NoOfDeposits;

    await expect(stakingContract.Withdraw(4)).not.to.be.reverted;
    await increaseTimeBy(22 * oneday);
    await expect(stakingContract.Withdraw(4)).to.be.revertedWith(
      "Withdraw not initiated"
    );

    var mydepositsAfter = (await stakingContract.userInfo(owner.address))
      .NoOfDeposits;

    expect(mydepositsAfter - mydepositsBefore).to.equal(0);
  });

  it("Should calculate action modifiers correctly", async function () {
    var increases = [1, 5, 1, 6, 3, 14];

    const initial = Number(await stakingContract.getDifferenceFromActionDay());

    await increaseTimeBy(increases[0] * oneday);

    await currentDifferenceFromActionDay();
    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      initial + increases[0]
    );
    await increaseTimeBy(increases[1] * oneday);

    await currentDifferenceFromActionDay();
    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      initial + increases[0] + increases[1]
    );
    await increaseTimeBy(increases[2] * oneday);

    await currentDifferenceFromActionDay();
    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      getres(initial + increases[0] + increases[1] + increases[2])
    );
    await increaseTimeBy(increases[3] * oneday);

    await currentDifferenceFromActionDay();
    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      getres(
        initial + increases[0] + increases[1] + increases[2] + increases[3]
      )
    );
    await increaseTimeBy(increases[4] * oneday);

    await currentDifferenceFromActionDay();
    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      getres(
        initial +
          increases[0] +
          increases[1] +
          increases[2] +
          increases[3] +
          increases[4]
      )
    );
    await increaseTimeBy(increases[5] * oneday);

    await currentDifferenceFromActionDay();

    expect(await stakingContract.getDifferenceFromActionDay()).to.equal(
      getres(
        initial +
          increases[0] +
          increases[1] +
          increases[2] +
          increases[3] +
          increases[4] +
          increases[5]
      )
    );
  });

  it("Should be able to deposit after withdrawing all funds", async function () {
    await stakingContract.deposit(toBN(depositamount, 18));

    await increaseTimeBy(60 * oneday);
    await expect(stakingContract.UnlockDeposit(6, 2)).not.to.be.reverted;

    await expect(stakingContract.ChangefeeAddress(wallet1.address)).not.to.be
      .reverted;

    await increaseTimeBy(8 * oneday);

    pendingbefore = await stakingContract.pendingWithdrawls(owner.address);
    await expect(stakingContract.Withdraw(6)).not.to.be.reverted;

    await stakingContract.deposit(toBN(depositamount, 18));

    await increaseTimeBy(63 * oneday);
    await expect(stakingContract.UnlockDeposit(7, 1)).not.to.be.reverted;

    await expect(stakingContract.InitiateClaim()).not.to.be.reverted;
    await increaseTimeBy(21 * oneday);
    await expect(stakingContract.Withdraw(2)).not.to.be.reverted;
    await expect(stakingContract.Claim()).not.to.be.reverted;

    await stakingContract.deposit(toBN(200 * depositamount, 18));

    await increaseTimeBy(60 * oneday);
    await expect(stakingContract.UnlockDeposit(8, 2)).not.to.be.reverted;
    await increaseTimeBy(10 * oneday);

    await expect(stakingContract.Withdraw(8)).not.to.be.reverted;
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
  var pending = await stakingContract.pendingReward(dep, user);
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

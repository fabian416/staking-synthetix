// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2 <0.9.0;

import "lib/forge-std/src/interfaces/IERC20.sol";

contract Staking {
    IERC20 public  stakeToken;
    IERC20 public  rewardToken;
    uint256 public immutable totalRewards;
    uint256 public rewardRate;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;
    uint256 public endWindowStake;
    uint256 public constant LOCK_PERIOD = 7 days;

    mapping(address => Staker)public stakers;
    uint256 totalStaked;

    event TokensWithdraw(address indexed  user, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event RewardsPaid(address indexed user, uint256 amount);

    struct Staker {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakedTime;
    }
    
    constructor (
        address _rewardTokenAddress
    ){
        rewardToken = IERC20(_rewardTokenAddress);
        lastUpdateBlock = block.number;
        totalRewards = 2_500_000_000 * 10e18;
        rewardRate = totalRewards / 691200; // represent rewardRate per block that would be 3616.89814815
        endWindowStake = block.timestamp + 30 days; // Staking window of 30 days

    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number; 
        if (account != address(0)){
            stakers[account].rewardDebt = earned(account);
        }
        _;
    }

    function rewardPerToken() public view returns(uint256) {
        if (totalStaked == 0 ){
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + 
        (block.number - lastUpdateBlock) * rewardRate * 1e18
        / totalStaked;
    }
    
    function stake(uint256 _amount) public updateReward(msg.sender) {
        Staker storage Stake = stakers[msg.sender];
        require(block.timestamp <= endWindowStake, "STAKE_WINDOW_CLOSE");
        require(_amount > 0, "INVALID_AMOUNT");
        totalStaked += _amount;
        Stake.amount += _amount;
        Stake.lastStakedTime = block.timestamp;

        emit TokensStaked(msg.sender, _amount);
    }
    function withdraw(uint256 _amount) public {
        Staker storage staker = stakers[msg.sender];
        require(block.timestamp >= staker.lastStakedTime +  LOCK_PERIOD, "LOCK_PERIOD_NOT_FINISHED_YET");
        require(_amount > 0, "INVALID_AMOUNT_TO_WITHDRAW");
        require(staker.amount > 0, "INSUFFICIENT AMOUNT TO WITHDRAW");
        
        totalStaked -= _amount;
        staker.amount -= _amount;

        require(stakeToken.transfer(msg.sender, _amount),"TRANSFER_FAILED");

        emit TokensWithdraw(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint256) {
        return stakers[_account].amount * (rewardPerToken() - stakers[_account].rewardDebt) /
        1e18;
    }

    function getReward() public updateReward(msg.sender) {
        Staker storage Stake = stakers[msg.sender];
        uint256 rewards = earned(msg.sender);
        if (rewards > 0 ){
            Stake.rewardDebt = 0;
            require(rewardToken.transfer(msg.sender, rewards), "TRANSFER_FAILED");

            emit RewardsPaid(msg.sender, rewards);

        }
    }
 }
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "./StakePool.sol";

/**
 * @dev https://bscswap.com
 * BSWAP will be halved at each period. Withdrawals will be allowed after the 75% of the genesis mining supply has been staked.
 * Forked from https://github.com/milk-protocol/stakecow-contracts-bsc/blob/master/contracts/FomoCow.sol
 */

contract GenesisPool is StakePool {
    IERC20 public bswapToken;

    // Halving period in seconds, should be defined as 3.5 days
    uint256 public halvingPeriod;
    // Total reward in 18 decimal
    uint256 public totalreward;
    // Starting timestamp for Genesis Staking Pool
    uint256 public starttime;
    // The timestamp when stakers should be allowed to withdraw
    uint256 public stakingtime;
    uint256 public eraPeriod = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalRewards = 0;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _depositToken, address _bswapToken, uint256 _halvingPeriod, uint256 _totalreward, uint256 _starttime, uint256 _stakingtime) public {
        super.initialize(_depositToken, msg.sender);
        bswapToken = IERC20(_bswapToken);

        halvingPeriod = _halvingPeriod;
        starttime = _starttime;
        stakingtime = _stakingtime;
        notifyRewardAmount(_totalreward.mul(50).div(100));
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, eraPeriod);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function stake(uint256 amount) public updateReward(msg.sender) checkhalve checkStart{
        require(amount > 0, "ERROR: Cannot stake 0");
        super._stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) checkhalve checkStart stakingTime{
        require(amount > 0, "ERROR: Cannot withdraw 0");
        super._withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external stakingTime{
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkhalve checkStart stakingTime{
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            bswapToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
            totalRewards = totalRewards.add(reward);
        }
    }

    modifier checkhalve(){
        if (block.timestamp >= eraPeriod) {
            totalreward = totalreward.mul(50).div(100);

            rewardRate = totalreward.div(halvingPeriod);
            eraPeriod = block.timestamp.add(halvingPeriod);
            emit RewardAdded(totalreward);
        }
        _;
    }

    modifier checkStart(){
        require(block.timestamp > starttime,"ERROR: Not start");
        _;
    }

    modifier stakingTime(){
        require(block.timestamp >= stakingtime,"ERROR: Staking not finished, you are not allowed to withdrawal yet");
        _;
    }

    function notifyRewardAmount(uint256 reward)
        internal
        updateReward(address(0))
    {
        if (block.timestamp >= eraPeriod) {
            rewardRate = reward.div(halvingPeriod);
        } else {
            uint256 remaining = eraPeriod.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(halvingPeriod);
        }
        totalreward = reward;
        lastUpdateTime = block.timestamp;
        eraPeriod = block.timestamp.add(halvingPeriod);
        emit RewardAdded(reward);
    }
}

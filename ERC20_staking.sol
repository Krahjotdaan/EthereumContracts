// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    
    event Transfer(address indexed from, address indexed to, uint256 indexed amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed amount);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address from, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
}

struct StakeStruct {
    uint256 tokenValue;
    uint256 stakeTime;
    uint256 unstakeTime;
}

contract Staking {
    
    mapping(address => mapping(address => StakeStruct)) public stakes;

    event Stake(address from, address token, uint256 value, uint256 unstakeTime);
    event Unstake(address to, address token, uint256 value);

    function makeStake(address token, uint256 value, uint256 unstakeTime) external {
        require(stakes[msg.sender][token].tokenValue == 0, "Staking: you already have a stake");
        require(unstakeTime > block.timestamp, "Staking: that time has passed");
        require(IERC20(token).allowance(msg.sender, address(this)) >= value, "Staking: not enough approved tokens to staking. Call function 'approve' to grant permission to staking to dispose of tokens");

        IERC20(token).transferFrom(msg.sender, address(this), value);
        stakes[msg.sender][token] = StakeStruct(value, block.timestamp, unstakeTime);

        emit Stake(msg.sender, token, value, unstakeTime);
    }

    function unstake(address token) external {
        require(stakes[msg.sender][token].tokenValue > 0, "Staking: you don't have a stake for this token");
        require(block.timestamp > stakes[msg.sender][token].unstakeTime, "Staking: it's not yet time to take the steak out");
        
        uint256 reward = calculateReward(msg.sender, token);
        IERC20(token).transfer(msg.sender, stakes[msg.sender][token].tokenValue);
        IERC20(token).mint(msg.sender, reward);

        emit Unstake(msg.sender, token, stakes[msg.sender][token].tokenValue + reward);
        stakes[msg.sender][token].tokenValue = 0;
    }

    function calculateReward(address owner, address token) internal view returns(uint256) {
        uint256 time = (block.timestamp - stakes[owner][token].stakeTime) / 12 hours;
        uint256 reward = 0;
        uint256 stake = stakes[owner][token].tokenValue;
        
        for (uint256 i = 0; i < time; i++) {
            reward += (stake + reward) / 100;
        }

        return reward;
    }
}

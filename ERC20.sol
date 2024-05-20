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
}

contract ERC20 is IERC20 {
    uint256 _totalSupply = 0;
    string _name;
    string _symbol;
    address owner;
    address public dao;
    uint8 _decimals;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 amount) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = amount;
        balances[msg.sender] = amount;
        owner = msg.sender;
    }

    // returns token name
    function name() public view returns (string memory) {
        return _name;
    }

    // returns token symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // returns token zeros amount
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    // returns token total emission
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // returns account balance to its address
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // returns number of tokens that <spender> can spend from <owner> address
    function allowance(address _owner, address spender) public view returns (uint256) {
        return allowed[_owner][spender];
    }

    // issuing permission to <spender> to spend amount of tokens from <msg.sender> address
    function approve(address spender, uint256 amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // increasing of <amount> of tokens that belong to msg.sender that <spender> can spend
    function increaseAllowance(address spender, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= allowed[msg.sender][spender] + amount, "ERC20: not enough tokens to allow");
        allowed[msg.sender][spender] += amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // decreasing of <amount> of tokens that belong to msg.sender that <spender> can spend
    function decreaseAllowance(address spender, uint256 amount) public returns (bool) { 
        allowed[msg.sender][spender] -= amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // sending <amount> of tokens to address <to> from address <msg.sender>
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "ERC20: not enough tokens to transfer");  
        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // sending <amount> of tokens to address <to> from address <from>
    // changing permission to spend tokens that belong to <from> for <msg.sender>
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "ERC20: not enough tokens to transfer");
        require(allowed[from][msg.sender] >= amount, "ERC20: no permission to spend");
        allowed[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;

        emit Approval(from, msg.sender, allowed[from][msg.sender]);
        emit Transfer(from, to, amount);
        return true;
    }

    // token emission
    function mint(address to, uint256 amount) external {
        require(msg.sender == dao, "ERC20: no permission to coinage");
        balances[to] += amount;
        _totalSupply += amount;
        
        emit Transfer(address(0), to, amount);
    }

    // token burning
    function burn(uint256 amount) external {
        require(balances[msg.sender] >= amount, "ERC20: not enough tokens to burn");
        balances[msg.sender] -= amount;
        _totalSupply -= amount;
        balances[address(0)] += amount;
        
        emit Transfer(msg.sender, address(0), amount);
    }

    // setting dao 
    function setDAO(address _dao) public {
        require(msg.sender == owner, "ERC20: You are not an owner");
        dao = _dao;
    }
}

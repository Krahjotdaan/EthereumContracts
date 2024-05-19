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

struct Lot {
    address tokenAddress;
    address tokenOwner;
    uint256 price;
    uint256 amount;
}

contract Marketplace {
    
    uint256 public lotId;
    mapping(uint256 => Lot) public list;

    event ListLot(uint256 lotId, address owner, address tokenAddress, uint256 price, uint256 amount);
    event Cancel(uint256 lotId, uint256 amount);
    event Purchase(uint256 lotId, address tokenAddress, uint256 price, uint256 amount, address customer);

    function listLot(address _tokenAddress, uint256 _price, uint256 _amount) external returns(uint256) {
        require(IERC20(_tokenAddress).allowance(msg.sender, address(this)) == _amount, "Marketplace: not enough approved tokens to marketplace. Call function 'approve' to grant permission to marketplace to dispose of tokens");

        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        lotId++;
        list[lotId] = Lot(_tokenAddress, msg.sender, _price, _amount);

        emit ListLot(lotId, msg.sender, _tokenAddress, _price, _amount);

        return lotId;
    }

    function cancel(uint256 _id, uint256 _amount) external {
        Lot memory lot = list[_id];
        address _tokenOwner = lot.tokenOwner;
        
        require(msg.sender == _tokenOwner, "Marketplace: you have not rights");
        require(lot.amount >= _amount, "Marketplace: too many tokens to cancel");

        IERC20(lot.tokenAddress).transfer( _tokenOwner, _amount);
        lot.amount -= _amount;

        if (lot.amount == 0) {
            delete list[_id];
        }
        
        emit Cancel(_id, _amount);
    }

    function purchase(uint256 _id, uint256 _amount) external payable {
        Lot memory lot = list[_id];
        require(msg.value >= lot.price * _amount, "Marketplace: not enough eth");
        require(lot.amount >= _amount, "Marketplace: too many tokens to purchase");

        payable(lot.tokenOwner).transfer(lot.price * _amount);
        IERC20(lot.tokenAddress).transfer(msg.sender, _amount);
        lot.amount -= _amount;

        if (msg.value > lot.price * _amount) {
            payable(msg.sender).transfer(msg.value - lot.price * _amount);
        }

        if (lot.amount == 0) {
            delete list[_id];
        }

        emit Purchase(_id, lot.tokenAddress, lot.price, _amount, msg.sender);
    }
}

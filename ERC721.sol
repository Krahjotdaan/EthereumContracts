// SPDX-License-Identifier: MIT
 
pragma solidity 0.8.19;
 
interface IERC165 {
 
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
 
interface IERC721Receiver {
 
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
 
interface IERC721 {
 
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
 
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
 
interface IERC721Metadata {
 
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

library String {
    // Функция для перевода числа в строку
    function toString(uint256 value) internal pure returns(string memory) {
        uint256 temp = value;
        uint256 digits;
        do {
            digits++;
            temp /= 10;
        } while (temp != 0);
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
 
abstract contract ERC165 is IERC165 {
 
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
 
contract ERC721 is IERC721, IERC721Metadata, ERC165 {

    using String for uint256;

    uint256 tokenId;
    string _name;
    string _symbol;
    string _baseUri;
    address _owner;
    mapping(uint256 => address) owners;
    mapping(address => uint256) balances;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;

    constructor(string memory name_, string memory symbol_, string memory baseUri_, address owner_) {
        _name = name_;
        _symbol = symbol_;
        _baseUri = baseUri_;
        _owner = owner_;
    }
 
    // возвращает название токена
    function name() public view returns (string memory) {
        return _name;
    }
 
    // возвращает символа токена
    function symbol() public view returns (string memory) {
        return _symbol;
    }
 
    // возвращает URI токена по его id
    function tokenURI(uint256 tokenId_) public view returns (string memory) {
        require(owners[tokenId_] != address(0), "ERC721: URI query for nonexistent token");
        return string.concat(_baseUri, String.toString(tokenId_));
    }
 
    // возвращает баланса аккаунта по его адресу
    function balanceOf(address owner_) external view returns (uint256) {
        return balances[owner_];
    }
 
    // возвращает адрес владельца токена по его id
    function ownerOf(uint256 tokenId_) external view returns (address) {
        return owners[tokenId_];
    }

    // проверка прав оператора на конкретный токен
    function getApproved(uint256 tokenId_) public view returns (address) {
        return tokenApprovals[tokenId_];
    }
 
    // проверка прав оператора на все токены
    function isApprovedForAll(address owner_, address operator_) public view returns (bool) {
        return operatorApprovals[owner_][operator_];
    }
    
    // функция эмиссии токенов
    function mint(address to) external returns (uint256) {
        require(msg.sender == _owner, "ERC721: you are not an owner");
        tokenId += 1;
        balances[to] += 1;
        owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        return tokenId;
    }
 
    // функция для установки прав оператора для одного конкретного токена
    function approve(address spender_, uint256 tokenId_) public {
        require(spender_ != owners[tokenId_], "ERC721: approval to current owner");
        require(msg.sender == owners[tokenId_] || 
        msg.sender == tokenApprovals[tokenId_] ||
        operatorApprovals[owners[tokenId_]][msg.sender], 
        "ERC721: you are not owner or approved");

        tokenApprovals[tokenId_] = spender_;
        emit Approval(msg.sender, spender_, tokenId);

    }
 
    // функция для установки прав оператора на все токены
    function setApprovalForAll(address operator_, bool approved_) public {
        require(msg.sender != operator_, "ERC721: approve to caller");
        operatorApprovals[msg.sender][operator_] = approved_;

        emit ApprovalForAll(msg.sender, operator_, approved_);
    }
 
    // функция трансфера без проверки адреса to_
    function transferFrom(address from_, address to_, uint256 tokenId_) external {
        require(from_ == owners[tokenId_], "ERC721: from is not an owner of token");
        require(msg.sender == owners[tokenId_] || 
        msg.sender == tokenApprovals[tokenId_] ||
        operatorApprovals[owners[tokenId_]][msg.sender], 
        "ERC721: you are not an owner or approved");
        tokenApprovals[tokenId_] = address(0);
        balances[from_] -= 1;
        balances[to_] += 1;
        owners[tokenId_] = to_;
        emit Transfer(from_, to_, tokenId_);
    }
 
    // функция трансфера с проверкой, что адрес to_ поддерживает интерфейс IERC721Receiver
    function safeTransferFrom(address from_, address to_, uint256 tokenId_) external {
        require(from_ == owners[tokenId_], "ERC721: from is not an owner of token");
        require(msg.sender == owners[tokenId_] || 
        msg.sender == tokenApprovals[tokenId_] ||
        operatorApprovals[owners[tokenId_]][msg.sender], 
        "ERC721: you are not an owner or approved");
        tokenApprovals[tokenId_] = address(0);
        balances[from_] -= 1;
        balances[to_] += 1;
        owners[tokenId_] = to_;
        emit Transfer(from_, to_, tokenId_);
        require(_checkOnERC721Received(from_, to_, tokenId_, msg.data));
    }
 
    // функция трансфера с проверкой, что адрес to_ поддерживает интерфейс IERC721Receiver
    function safeTransferFrom(address from_, address to_, uint256 tokenId_, bytes memory data_) public {
        require(from_ == owners[tokenId_], "ERC721: from is not an owner of token");
        require(msg.sender == owners[tokenId_] || 
        msg.sender == tokenApprovals[tokenId_] ||
        operatorApprovals[owners[tokenId_]][msg.sender], 
        "ERC721: you are not an owner or approved");
        tokenApprovals[tokenId_] = address(0);
        balances[from_] -= 1;
        balances[to_] += 1;
        owners[tokenId_] = to_;
        emit Transfer(from_, to_, tokenId_);
        require(_checkOnERC721Received(from_, to_, tokenId_, data_));
    }

    // функция проверки поддержки целевым контрактом ERC721
    function _checkOnERC721Received(address from_, address to_, uint256 tokenId_, bytes memory data_) private returns (bool) {
        if (to_.code.length > 0) { 
            try IERC721Receiver(to_).onERC721Received(msg.sender, from_, tokenId_, data_) returns (bytes4 response) {
                return response == IERC721Receiver.onERC721Received.selector;
            } 
            catch {    
                return false;
            }
        } 
        else { 
            return true; 
        }
    }

    function supportsInterface(bytes4 interfaceId_) public view override returns(bool) {
        return type(IERC721).interfaceId == interfaceId_ || 
        type(IERC721Metadata).interfaceId == interfaceId_ ||
        super.supportsInterface(interfaceId_);
    }
}

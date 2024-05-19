// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

library Strings {
 
    function toString(uint256 value) internal pure returns (string memory) {
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
 
library Address {
 
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
 
interface IERC165 {
 
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
 
interface IERC1155 is IERC165 {
 
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool indexed approved);
    event URI(string indexed value, uint256 indexed id);
 
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[][] memory);
}
 
interface IERC1155Receiver is IERC165 {
 
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}
 
interface IERC1155MetadataURI is IERC1155 {
 
    function uri(uint256 id) external view returns (string memory);
}
 
abstract contract ERC165 is IERC165 {
 
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
 
contract MyERC1155 is ERC165, IERC1155, IERC1155MetadataURI {

    using Address for address;
    using Strings for uint256;

    string public name;
    string public symbol;
    string baseUri;
    address owner;
    mapping(uint256 => bool) tokenIds;
    mapping(uint256 => mapping(address => uint256)) balances;
    mapping(address => mapping(address => bool)) operatorApprovals;

    constructor(string memory _name, string memory _symbol, string memory _baseUri, address _owner) {
        name = _name;
        symbol = _symbol;
        baseUri = _baseUri;
        owner = _owner;
    }
 
    // функция эмиссии одного токена
    function mint(address to, uint256 _tokenId, uint256 amount) external {
        require(msg.sender == owner, "ERC1155: you are not an owner");
        balances[_tokenId][to] += amount;

        emit TransferSingle(msg.sender, address(0), to, _tokenId, amount);
    }
 
    // функция эмиссии нескольких токенов на несколько адресов
    function mintBatch(address to, uint256[] calldata _tokenIds, uint256[] calldata amounts) external {
        require(msg.sender == owner, "ERC1155: you are not an owner");
        require(_tokenIds.length == amounts.length, "ERC1155: tokenIds and amounts have different lengths");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            balances[_tokenIds[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), to, _tokenIds, amounts);
    }

    // функция сжигания одного токена
    function burn(uint256 _tokenId, uint256 amount) external {
        require(tokenIds[_tokenId], "ERC1155: token does not exist");
        require(balances[_tokenId][msg.sender] >= amount, "ERC1155: too many tokens to burn");
        balances[_tokenId][msg.sender] -= amount;
        balances[_tokenId][address(0)] += amount;

        emit TransferSingle(msg.sender, msg.sender, address(0), _tokenId, amount);
    }

    // функция сжигания нескольких токенов
    function burnBatch(uint256[] calldata _tokenIds, uint256[] calldata amounts) external {
        require(_tokenIds.length == amounts.length, "ERC1155: tokenIds and amounts have different lengths");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(tokenIds[_tokenIds[i]], "ERC1155: token does not exist");
            require(balances[_tokenIds[i]][msg.sender] >= amounts[i], "ERC1155: too many tokens to burn");
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            balances[_tokenIds[i]][msg.sender] -= amounts[i];
            balances[_tokenIds[i]][address(0)] += amounts[i];
        }

        emit TransferBatch(msg.sender, msg.sender, address(0), _tokenIds, amounts);
    }
 
    // функция назначения оператора
    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator, "ERC1155: approve to caller");
        operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }
 
    // функция отправки amount токенов из коллекции id
    function safeTransferFrom(address from, address to, uint256 _tokenId, uint256 amount, bytes calldata data) external {
        require(tokenIds[_tokenId], "ERC1155: token does not exist");
        require(operatorApprovals[from][msg.sender] || from == msg.sender, "ERC1155: you are not an owner or approved operator");
        require(balances[_tokenId][from] >= amount, "ERC1155: not enough tokens");
        require(_doSafeSingleTransferAcceptanceCheck(msg.sender, from, to, _tokenId, amount, data), "ERC1155: address to does not support ERC1155");

        balances[_tokenId][from] -= amount;
        balances[_tokenId][to] += amount;

        emit TransferSingle(msg.sender, from, to, _tokenId, amount);
    }
 
    // функция отправки amounts токенов из коллекций ids
    function safeBatchTransferFrom(address from, address to, uint256[] calldata _tokenIds, uint256[] calldata amounts, bytes calldata data) external {
        require(_doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, _tokenIds, amounts, data), "ERC1155: address to does not support ERC1155");
        require(_tokenIds.length == amounts.length, "ERC1155: tokenIds and amounts have different lengths");
        require(operatorApprovals[from][msg.sender] || from == msg.sender, "ERC1155: you are not an owner or approved operator");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(tokenIds[_tokenIds[i]], "ERC1155: token does not exist");
            require(balances[_tokenIds[i]][from] >= amounts[i], "ERC1155: not enough tokens");
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            balances[_tokenIds[i]][from] -= amounts[i];
            balances[_tokenIds[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, from, to, _tokenIds, amounts);
    }
 
    // эта функция нужна для проверки поддерживаемых интерфейсов
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC1155MetadataURI).interfaceId || super.supportsInterface(interfaceId);
    }

    // функия проверки прав оператора
    function isApprovedForAll(address account, address operator) external view returns (bool) {
        return operatorApprovals[account][operator];
    }

    // возвращает URI токена по id коллекции
    function uri(uint256 _tokenId) external view returns (string memory) {
        require(tokenIds[_tokenId], "ERC1155: token does not exist");
        return string.concat(baseUri, _tokenId.toString());
    }
 
    // возвращает баланса аккаунта по его адресу и id коллекции токенов
    function balanceOf(address account, uint256 _tokenId) external view returns (uint256) {
        return balances[_tokenId][account];
    }
 
    // Функция получения баланса нескольких аккаунтов
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata _tokenIds) external view returns (uint256[][] memory) {
        uint256[][] memory result;
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256[] memory tmp;
            for (uint256 j = 0; j < _tokenIds.length; j++) {
                tmp[j] = balances[_tokenIds[j]][accounts[i]];
            }
            result[i] = tmp;
        }
        return result;
    }

    // проверка аккаунта, на который отправляется токен
    function _doSafeSingleTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data) private returns(bool){
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                return response == IERC1155Receiver.onERC1155Received.selector;
            } catch {
                return false;
            }
        } 
        else {
            return true;
        }
    }

    // проверка аккаунтов, на который отправляются токены
    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private returns(bool) {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                return response == IERC1155Receiver.onERC1155BatchReceived.selector;
            } catch {
                return false;
            }
        } 
        else {
            return true;
        }
    }
}

// SPDX-License-Identifier: MIT
 
pragma solidity 0.8.19;
 
interface IERC165 {
 
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
 
interface IERC721Metadata {
 
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
 
interface IERC721 {
 
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool indexed approved);
 
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

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

struct Item {
    uint256 tokenId;
    uint256 price;
    address tokenAddress;
    address tokenOwner;
}

struct AuctionItem {
    uint256 tokenId;
    uint256 currentPrice;
    uint256 time;
    uint256 bidCount;
    address tokenAddress;
    address tokenOwner;
    address lastCustomer;
}
 
contract Marketplace {

    uint256 public listId;
    uint256 public listAuctionId;
    mapping(uint256 => Item) public list;
    mapping(uint256 => AuctionItem) public listAuction;

    event ListItem(address tokenAddress, uint256 tokenId, uint256 price);
    event ListItemOnAuction(address tokenAddress, uint256 tokenId, uint256 minPrice);
    event Cancel(uint256 tokenId);
    event BuyItem(address tokenAddress, uint256 tokenId, address customer, uint256 price);
    event MakeBid(uint256 auctionId, address customer, uint256 newBid);
    event FinishAuction(uint256 auctionId, address tokenAddress, address customer, uint256 price, bool result);

    modifier isERC721(address to) {
        require(_isERC721(to), "Marketplace: this address is not a contract or ERC721");
        _;
    }

    modifier isOwner(address to, uint256 id) {
        IERC721 c = IERC721(to);
        address _tokenOwner = c.ownerOf(id);

        require(msg.sender == _tokenOwner ||
        msg.sender == c.getApproved(id) ||
        c.isApprovedForAll(_tokenOwner, msg.sender), 
        "Marketplace: you have not rights");
        _;
    }

    function encryptData(bool _choice, uint256 _price) public pure returns(bytes memory) {
        return abi.encode(_choice, _price);
    }

    function checkOnERC721Received(address, uint256 _tokenId, bytes memory _data) external isERC721(msg.sender) returns (bytes4) {
        require(address(this) == IERC721(msg.sender).ownerOf(_tokenId), "Marketplace: marketplace is not an owner");

        (bool choice, uint256 price) = abi.decode(_data, (bool, uint256));
        choice ? listItem(msg.sender, _tokenId, price) : listItemOnAuction(msg.sender, _tokenId, price);
        return this.checkOnERC721Received.selector;
    }
 
    // функция для выставления токена на продажу
    function listItem(address _tokenAddress, uint256 _tokenId, uint256 _price) internal returns(uint256) {
        IERC721 c = IERC721(_tokenAddress);
        address _tokenOwner = c.ownerOf(_tokenId);
        listId++;
        list[listId] = Item(
            _tokenId,
            _price,
            _tokenAddress,
            _tokenOwner
        );
        
        emit ListItem(_tokenAddress, _tokenId, _price);

        return listId;
    }
 
    // покупка токена
    function buyItem(uint256 _id) external payable {
        Item memory item = list[_id];
        require(item.tokenOwner != address(0), "Marketplace: this token not on sale");
        require(msg.value >= list[_id].price, "Marketplace: not enough eth");

        payable(item.tokenOwner).transfer(item.price);
        IERC721(item.tokenAddress).transferFrom(address(this), msg.sender, item.tokenId);
        if (msg.value > item.price) {
            payable(msg.sender).transfer(msg.value - item.price);
        }

        delete list[_id];

        emit BuyItem(item.tokenAddress, _id, msg.sender, item.price);
    }
 
    // функция снятия токена с продажи
    function cancel(uint256 _id) external {
        Item memory item = list[_id];
        address _tokenOwner = item.tokenOwner;
        
        require(msg.sender == _tokenOwner ||
        IERC721(item.tokenAddress).isApprovedForAll(_tokenOwner, msg.sender), 
        "Marketplace: you have not rights");

        IERC721(item.tokenAddress).transferFrom(address(this), _tokenOwner, item.tokenId);
        delete list[_id];

        emit Cancel(_id);
    }
 
    // функция для выставления токена на аукцион
    function listItemOnAuction(address _tokenAddress, uint256 _tokenId, uint256 _minPrice) internal returns(uint256) {    
        IERC721 c = IERC721(_tokenAddress);
        address _tokenOwner = c.ownerOf(_tokenId);
        listAuctionId++;
        listAuction[listAuctionId] = AuctionItem(
            _tokenId,
            _minPrice,
            block.timestamp + 24 hours,
            0,
            _tokenAddress,
            _tokenOwner,
            address(0)
        );

        emit ListItemOnAuction(_tokenAddress, _tokenId, _minPrice);

        return listAuctionId;
    }
 
    // функция, чтобы делать ставку в аукционе
    function makeBid(uint256 _id) external payable returns(bool) {
        AuctionItem memory item = listAuction[_id];
        
        require(msg.value > item.currentPrice, "Marketplace: this bid is equal or lower then currentPrice");
        require(block.timestamp < item.time, "Marketplace: auction is over");

        if (item.lastCustomer != address(0)) {
            payable(item.lastCustomer).transfer(item.currentPrice);
        }

        item.bidCount++;
        item.currentPrice = msg.value;
        item.lastCustomer = msg.sender;

        emit MakeBid(_id, item.lastCustomer, item.currentPrice);

        return true;
    }
 
    // функция завершения аукциона
    function finishAuction(uint256 _id) external {
        AuctionItem memory item = listAuction[_id];
        require(block.timestamp >= item.time, "Marketplace: auction is not over");

        IERC721 c = IERC721(item.tokenAddress);

        if (item.bidCount < 3) {
            c.transferFrom(address(this), c.ownerOf(item.tokenId), item.tokenId);
            payable(item.lastCustomer).transfer(item.currentPrice);

            emit FinishAuction(_id, item.tokenAddress, item.lastCustomer, item.currentPrice, false);
        }
        else {
            c.transferFrom(address(this), item.lastCustomer, item.tokenId);
            payable(item.tokenOwner).transfer(item.currentPrice);

            emit FinishAuction(_id, item.tokenAddress, item.lastCustomer, item.currentPrice, true);
        }

        delete listAuction[_id];

    }

    function _isERC721(address to) internal view returns(bool result) {
        if (to.code.length > 0) {
            try IERC165(to).supportsInterface(type(IERC721).interfaceId) returns (bool response1) {
                if (response1) {
                    try IERC165(to).supportsInterface(type(IERC721Metadata).interfaceId) returns (bool response2) {
                        return response2;
                    } 
                    catch {}
                }
            }
            catch {
                return false;
            }
        }
        else {
            return false;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <8.10.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract NFTAuction is IERC1155Receiver, IERC721Receiver, ERC165 {
    bytes4 private constant CONTRACT1155INTERFACE = 0xd9b67a26;
    enum Status {
        Ongoing,
        Fail,
        Success
    }

    //拍卖对象
    struct Auction {
        //map token ID to
        uint128 auctionBidPeriod; // 拍卖持续时间
        uint128 auctionEnd; //拍卖结束时间
        uint256 despoitAmount;
        uint256 startPrice;
        uint256 minPrice; //目前最小出价
        Status status;
        address minPriceAddress;
        uint256 tokenId; //NFT tokenId
        address nftSeller; //卖家
        address nftContractAddress; // NFT合约地址
        uint256 amount; //token数量 1为721 ，大于1 为1155
        uint256 bidAmount;
        mapping(uint256 => address) list; //map的索引
        mapping(address => uint256) biders; //出价人
    }
    mapping(address => string) tokenUris;

    address[] currentBids;
    mapping(address => uint256) public refunds; //退款资金
    address[] public currentActions;

    mapping(address => Auction) public autions; //根据拍卖id 对应的拍卖
    mapping(address => address) public userAution; //根据用户账户对应的拍卖id

    uint32 public defaultAuctionBidPeriod; //默认拍卖持续时间
    uint256 public defaultAssestLockAmount; //默认拍卖锁定资金

    event PublishSuccess(
        address indexed contractAddresss,
        address from,
        address to,
        uint256 tokenid,
        uint256 amount
    );

    event Bid(
        address indexed bidAddress,
        uint256 price,
        address bider,
        uint256 count
    );

    event Over(address indexed bidAddress, Status status);

    event Settle(
        address indexed bidAddress,
        address indexed contractAddresss,
        uint256 tokenId,
        uint256 minPrice
    );
    event Widthdraw(address indexed to, uint256 amount);

    constructor() {
        defaultAuctionBidPeriod = 86400; //1 day
        defaultAssestLockAmount = 1 ether;
    }

    modifier autionNotStart(address _nftContractAddress, uint256 _tokenId) {
        require(
            autions[autionAddress(_nftContractAddress, _tokenId)].startPrice ==
                0,
            "n2"
        );
        _;
    }

    function autionOngoing(address bidAddress) internal view returns (bool) {
        return
            autions[bidAddress].startPrice != 0 ||
            block.timestamp < autions[bidAddress].auctionEnd;
    }

    function getActions() public view returns (address[] memory) {
        return currentActions;
    }

    function autionOverTime(address bidAddress) internal view returns (bool) {
        return
            autions[bidAddress].status == Status.Ongoing &&
            block.timestamp > autions[bidAddress].auctionEnd &&
            autions[bidAddress].auctionEnd != 0;
    }

    function setBiders(address bidId) public {
        delete currentBids;
        Auction storage aution = autions[bidId];

        for (uint256 i = 1; i <= aution.bidAmount; i++) {
            currentBids.push(aution.list[i]);
        }

        //      assembly{
        //    let memOffset:= mload(0x40)
        //     mstore(memOffset,0x20)

        //      mstore (add(memOffset,32),len)
        //      mstore(add(memOffset,32),)
        //      }
    }

    function getBiders() public view returns (address[] memory) {
        return currentBids;
    }

    function autionAddress(address _nftContractAddress, uint256 _tokenId)
        internal
        pure
        returns (address)
    {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(_nftContractAddress, _tokenId)
                        )
                    )
                )
            );
    }

    function _safeCall721(IERC721 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "ERC721: call failed");

        if (returndata.length > 0) {
            require(
                abi.decode(returndata, (bool)),
                "ERC721: operation did not succeed"
            );
        }
    }

    function _safeCall1155(IERC1155 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "ERC1155: call failed");

        if (returndata.length > 0) {
            require(
                abi.decode(returndata, (bool)),
                "ERC155: operation did not succeed"
            );
        }
    }

    function is1155Interface(IERC165 erc165) private view returns (bool) {
        return erc165.supportsInterface(CONTRACT1155INTERFACE);
    }

    // 发起拍卖
    function publishAution(
        address _nftContractAddress,
        uint256 _tokenId,
        uint128 _startPrice,
        uint256 _amount,
        string memory _uri
    ) external payable autionNotStart(_nftContractAddress, _tokenId) {
        require(_tokenId != 0, "n1");
        require(_nftContractAddress != address(0));
        require(_startPrice > 0, "n4");
        require(_amount > 0, "n5");
        require(msg.value >= defaultAssestLockAmount, "n6");
        address _aution = autionAddress(_nftContractAddress, _tokenId);
        userAution[msg.sender] = _aution;
        autions[_aution].auctionBidPeriod = defaultAuctionBidPeriod;
        autions[_aution].auctionEnd =
            defaultAuctionBidPeriod +
            uint64(block.timestamp);
        autions[_aution].startPrice = _startPrice;
        autions[_aution].tokenId = _tokenId;
        tokenUris[_aution] = _uri;
        autions[_aution].nftSeller = msg.sender;
        autions[_aution].nftContractAddress = _nftContractAddress;
        autions[_aution].amount = _amount;
        autions[_aution].status = Status.Ongoing;
        autions[_aution].despoitAmount = msg.value;
        currentActions.push(_aution);
        safeTransferFromCall(
            _nftContractAddress,
            msg.sender,
            address(this),
            _tokenId,
            _amount
        );
        emit PublishSuccess(
            _nftContractAddress,
            msg.sender,
            address(this),
            _tokenId,
            _amount
        );
    }

    function safeTransferFromCall(
        address _nftContractAddress,
        address from,
        address to,
        uint256 _tokenId,
        uint256 amount
    ) private {
        IERC165 caller = IERC165(_nftContractAddress);

        if (is1155Interface(caller)) {
            IERC1155 call1155 = IERC1155(_nftContractAddress);
            _safeCall1155(
                call1155,
                abi.encodeWithSelector(
                    call1155.safeTransferFrom.selector,
                    from,
                    to,
                    _tokenId,
                    amount,
                    ""
                )
            );
        } else {
            IERC721 call721 = IERC721(_nftContractAddress);
            _safeCall721(
                call721,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256",
                    from,
                    to,
                    _tokenId
                )
            );
        }
    }

    function remove(address el) public {
        uint256 index;
        for (index = 0; index < currentActions.length; index++) {
            if (currentActions[index] == el) {
                break;
            }
        }
        if (index == 0 && currentActions[0] != el) return;

        if (index >= currentActions.length) return;
        if (index == 0) {
            currentActions.pop();
        } else {
            currentActions[index] = currentActions[currentActions.length - 1];
            currentActions.pop();
        }
        // delete currentActions[currentActions.length];
    }

    function getMinPrice(address bidId)
        public
        view
        returns (
            uint256,
            address,
            uint256
        )
    {
        return (
            autions[bidId].minPrice,
            autions[bidId].minPriceAddress,
            autions[bidId].despoitAmount
        );
    }

    //竞标
    function bid(address bidId) external payable {
        require(autionOngoing(bidId), "n1");
        Auction storage aution = autions[bidId];
        require(msg.value >= aution.startPrice, "n2");
        require(aution.status == Status.Ongoing, "n3");
        // require(msg.value  > aution.minPrice,"n3");
        if (aution.bidAmount < aution.amount) {
            if (aution.minPrice == 0 || aution.minPrice > msg.value) {
                aution.minPrice = msg.value;
                aution.minPriceAddress = msg.sender;
            }
            aution.bidAmount += 1;
            if (aution.biders[msg.sender] > msg.value) {
                revert("n4");
            }
            if (aution.biders[msg.sender] > 0) {
                //如果之前 参与过 退回之前的钱
                payable(msg.sender).transfer(aution.biders[msg.sender]);
            }
            aution.biders[msg.sender] = msg.value;
            aution.list[aution.bidAmount] = msg.sender;
        } else {
            if (
                aution.minPrice > msg.value ||
                aution.minPriceAddress == address(0)
            ) {
                revert("min price less !");
            }
            uint256 index;
            for (uint256 i = 1; i <= aution.bidAmount; i++) {
                if (aution.list[i] == aution.minPriceAddress) {
                    index = i;
                }
            }

            aution.list[index] = msg.sender;
            delete aution.biders[aution.minPriceAddress];
            if (aution.biders[msg.sender] > msg.value) {
                revert("n4");
            }
            if (aution.biders[msg.sender] > 0) {
                //如果之前 参与过 退回之前的钱
                payable(msg.sender).transfer(aution.biders[msg.sender]);
            }
            aution.biders[msg.sender] = msg.value;
            uint256 _min_price = aution.biders[aution.list[1]];
            for (uint256 i = 1; i <= aution.bidAmount; i++) {
                if (aution.biders[aution.list[i]] < _min_price) {
                    _min_price = aution.biders[aution.list[i]];
                    index = i;
                }
            }
            aution.minPrice = _min_price;
            aution.minPriceAddress = aution.list[index];
            // aution.bidAmount += 1;
        }
        emit Bid(bidId, msg.value, msg.sender, aution.bidAmount);
    }

    //任何人都可以触发结束拍卖
    function overAution(address bidId) external {
        require(autionOverTime(bidId), "n1");

        Auction storage aution = autions[bidId];
        if (aution.bidAmount < aution.amount) {
            aution.status = Status.Fail;
            for (uint256 i = 1; i <= aution.bidAmount; i++) {
                refunds[aution.list[i]] +=
                    refunds[aution.list[i]] +
                    aution.biders[aution.list[i]] +
                    aution.despoitAmount /
                    aution.bidAmount;
                delete aution.biders[aution.list[i]];
                delete aution.list[i];
            }
            safeTransferFromCall(
                aution.nftContractAddress,
                address(this),
                aution.nftSeller,
                aution.tokenId,
                aution.amount
            );
            remove(bidId);
        } else {
            aution.status = Status.Success;
        }
        emit Over(bidId, aution.status);
    }

    // 只有拍卖者能对成功拍卖进行发放
    function autionConfirm(address bidId) external {
        Auction storage aution = autions[bidId];
        require(msg.sender == aution.nftSeller, "n1");
        require(aution.status == Status.Success, "n2");
        for (uint256 i = 1; i <= aution.bidAmount; i++) {
            // 返回多余的资金
            if (aution.biders[aution.list[i]] > aution.minPrice) {
                refunds[aution.list[i]] =
                    aution.biders[aution.list[i]] +
                    refunds[aution.list[i]] -
                    aution.minPrice;
            }
            safeTransferFromCall(
                aution.nftContractAddress,
                address(this),
                aution.list[i],
                aution.tokenId,
                1
            ); //发放NFT
        }
        refunds[aution.nftSeller] =
            refunds[aution.nftSeller] +
            aution.minPrice *
            aution.bidAmount +
            aution.despoitAmount;
        remove(bidId);
        emit Settle(
            bidId,
            aution.nftContractAddress,
            aution.tokenId,
            aution.minPrice
        );
    }

    function getAutionApplyNumber(address bidId) public view returns (uint256) {
        return autions[bidId].bidAmount;
    }

    //取款
    function widthdraw() external {
        require(refunds[msg.sender] > 0, "n1");
        uint256 amount = refunds[msg.sender];
        refunds[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit Widthdraw(msg.sender, amount);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

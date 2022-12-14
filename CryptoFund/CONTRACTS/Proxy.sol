// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

import "./Interfaces/IProxy.sol";

contract Proxy is IProxy
{
    address immutable owner;

    address public exchangeContract;
    address public storageContract;
	address public commissionContract;
	address public opsContract;
	address public token;
    mapping (address => uint) public trustedContracts;

    constructor()
    {
        owner = msg.sender;
    }

    modifier OnlyOwner()
    {
        require(msg.sender == owner, "Sender not owner");
        _;
    }

    function multicall(bytes[] calldata data, address[] calldata contractAddr) external virtual override returns (bytes[] memory results)
    {
        for(uint i = 0; i < contractAddr.length; i++) require(trustedContracts[contractAddr[i]] == 1, "Contract not trusted");
        //https://ethereum.stackexchange.com/questions/83528/how-can-i-get-the-revert-reason-of-a-call-in-solidity-so-that-i-can-use-it-in-th/83577#83577
        results = new bytes[](data.length);
        for(uint i = 0; i < data.length; i++)
        {
            (bool success, bytes memory result) = address(contractAddr[i]).delegatecall(data[i]);
            if (!success)
            {
                if (result.length < 68) revert();
                assembly {result := add(result, 0x04)}
                revert(abi.decode(result, (string)));
            }
            results[i] = result;
        }
    }

    function initAddrs(address exchangeAddr, address storageAddr, address commissionAddr, address opsAddr, address tokenAddr) external OnlyOwner
    {
        exchangeContract = exchangeAddr;
        trustedContracts[exchangeAddr] = 1;
        storageContract = storageAddr;
        trustedContracts[storageAddr] = 1;
        commissionContract = commissionAddr;
        trustedContracts[commissionAddr] = 1;
        opsContract = opsAddr;
        trustedContracts[opsAddr] = 1;
        token = tokenAddr;
        trustedContracts[tokenAddr] = 1;
    }

    function setExchangeAddr(address exchangeAddr) external
    {
        address oldExchangeAddr = exchangeContract;
        require(msg.sender == oldExchangeAddr, "Sender not old SCExchange");
        trustedContracts[oldExchangeAddr] = 0;
        exchangeContract = exchangeAddr;
        trustedContracts[exchangeAddr] = 1;
    }

    function setStorageAddr(address storageAddr) external
    {
        address oldStorageAddr = storageContract;
        require(msg.sender == oldStorageAddr, "Sender not old SCStorage");
        trustedContracts[oldStorageAddr] = 0;
        storageContract = storageAddr;
        trustedContracts[storageAddr] = 1;
    }

    function setCommissionAddr(address commissionAddr) external
    {
        address oldCommissionAddr = commissionContract;
        require(msg.sender == oldCommissionAddr, "Sender not old SCCommission");
        trustedContracts[oldCommissionAddr] = 0;
        commissionContract = commissionAddr;
        trustedContracts[commissionAddr] = 1;
    }

    function setOpsAddr(address opsAddr) external
    {
        address oldOpsAddr = opsContract;
        require(msg.sender == oldOpsAddr, "Sender not old SCOps");
        trustedContracts[oldOpsAddr] = 0;
        opsContract = opsAddr;
        trustedContracts[opsAddr] = 1;
    }

    function setTokenAddr(address tokenAddr) external
    {
        address oldTokenAddr = token;
        require(msg.sender == oldTokenAddr, "Sender not old Token");
        trustedContracts[oldTokenAddr] = 0;
        token = tokenAddr;
        trustedContracts[tokenAddr] = 1;
    }

    function deleteContract(address newAddr) external virtual override OnlyOwner
    {
        //(address exchangeC, address storageC, address commissionC, address opsC, address tokenC) = (exchangeContract, storageContract, commissionContract, opsContract, token);
        //newAddr.delegatecall(abi.encodeWithSignature("initAddrs(address,address,address,address,address)", exchangeC, storageC, commissionC, opsC, tokenC));
        ISCCommission(commissionContract).updateProxy(newAddr);
        ISCExchange(exchangeContract).updateProxy(newAddr);
        ISCOps(opsContract).updateProxy(newAddr);
        ISCStorage(storageContract).updateProxy(newAddr);
        selfdestruct(payable(owner));
    }

    receive() external payable
    {
        revert();
    }
    
    fallback() external payable
    {
        revert();
    }
}
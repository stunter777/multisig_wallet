//SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.0; 

contract Ownable {
    address[] public owners;
    mapping(address => bool) isOwner;
    event Deposit(address _from,uint _amount);
    event Submit(uint txId);
    event Approve(address approver,uint _txId);

    constructor(address[] memory _owners) {
        require(_owners.length > 0, "no owners!");
        for(uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "zero address");
            require(!isOwner[owner],"already owner!");

            owners.push(owner);
            isOwner[owner] = true;
        }
    } 
    modifier onlyOwners() {
        require(isOwner[msg.sender],"not an owner!");
        _;
    }
}
contract Multisig is Ownable {
    uint public requiredApprovals;
    struct Tx{
        address _to;
        uint _value;
        bytes _data;
        bool _executed;
    }
    Tx[] public txs;
    mapping(uint => uint) public approvalsCount;
    mapping(uint => mapping(address => bool)) public approved;
    constructor(address[] memory _owners ,uint _requiredApprovals) Ownable(_owners) {
        require(_requiredApprovals >0 && _requiredApprovals <= owners.length, "doesn't make sense");
        requiredApprovals = _requiredApprovals;
    }

    receive() external payable {
        deposit();
    }
    
    function submit(address _to,uint _value, bytes calldata _data) external onlyOwners {
        Tx memory newTx = Tx({
            _to:_to,
            _value:_value,
            _data:_data,
            _executed:false
        });
        txs.push(newTx);
        emit Submit(txs.length - 1);
    }
    function deposit() public payable {
        emit Deposit(msg.sender,msg.value);
    }
    function encode(string memory _func, string memory _arg) public pure returns(bytes memory){
        return abi.encodeWithSignature(_func,_arg);
    }
    modifier txExists(uint _txId){
        require(_txId < txs.length, "tx does not exist");
        _;
    }
    modifier notApproved(uint _txId){
        require(!_isApproved(_txId,msg.sender), "tx already approved");
        _;
    }
    modifier notExecuted(uint _txId){
        require(!txs[_txId]._executed,"tx already executed");
        _;
    }
    modifier wasApproved(uint _txId){
        require(_isApproved(_txId,msg.sender), "tx not approved");
        _;
    }
    modifier enoughApprovals(uint _txId) {
        require(approvalsCount[_txId] >= requiredApprovals,"not enough approvals");
        _;
    }

    function _isApproved(uint _txId,address _addr) private view returns(bool){
        return approved[_txId][_addr];
    }

    function approve(uint _txId) 
    external 
    onlyOwners 
    txExists(_txId) 
    notApproved(_txId) 
    notExecuted(_txId) {

    approved[_txId][msg.sender] = true;
    approvalsCount[_txId] +=1;
    emit Approve(msg.sender,_txId);
    
        
    }

    function revoke(uint _txId) 
    external
    onlyOwners
    txExists(_txId)
    notExecuted(_txId)
    wasApproved(_txId)
    {
        approved[_txId][msg.sender] = false;
        approvalsCount[_txId] -=1;
    }

    function execute(uint _txId)
    external
    txExists(_txId)
    notExecuted(_txId)
    wasApproved(_txId)
    enoughApprovals(_txId)
    {
        Tx storage transaction = txs[_txId];
        (bool success,) = transaction._to.call{value:transaction._value}(transaction._data);
        require (success,"failed to exec");
        transaction._executed = true;
    }
    
}
contract Receiver {
    string public message;
    function getBalance() public view returns(uint){
        return address(this).balance;
    }
    function getMoney(string memory _msg) external payable {
        message = _msg;
    }
}
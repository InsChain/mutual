pragma solidity ^0.4.20;

interface PolicyPoolInterface{
    function joinWithCandy(address, uint256, uint256) onlyAgent public returns (bool);
}

contract PoolAgent{
    address public owner;
    address public newOwner;
    PolicyPoolInterface pool;

    event OwnerUpdate(address _prevOwner, address _newOwner);
    
    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }
    
    function PoolAgent(address poolAddr) public{
        pool=PolicyPoolInterface(poolAddr);
        owner = msg.sender;
    }
    
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = 0x0;
    }
    
    
    function testAgent(uint256 payload, uint256 timestamp) onlyOwner public returns (bool success){
        require(pool.joinWithCandy(msg.sender, payload, timestamp));
        
        return true;
    }

    // Destroy contract.
    function kill() public {
        require(msg.sender == owner);
        selfdestruct(msg.sender);
    }
}
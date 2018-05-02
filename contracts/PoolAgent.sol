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
    
    
    mapping(bytes => bool) usedNonces;
    PolicyPoolInterface pool;
    
    function PoolAgent(address poolAddr) public {
        pool=PolicyPoolInterface(poolAddr);
        owner = msg.sender;
    }



    function claimPolicy(uint256 payload, bytes nonce, bytes sig) public returns (bool){
        require(!usedNonces[nonce]);
        usedNonces[nonce] = true;

        // This recreates the message that was signed on the client.
        bytes32 message = prefixed(nonce);

        require(recoverSigner(message, sig) == msg.sender);
        require(pool.joinWithCandy(msg.sender, payload, now));
        
        return true;
    }

    // Destroy contract.
    function kill() public {
        require(msg.sender == owner);
        selfdestruct(msg.sender);
    }


    // Signature methods

    function splitSignature(bytes sig) internal pure returns (uint8, bytes32, bytes32) {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes sig) internal pure returns (address){
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes hash) internal pure returns (bytes32) {
        return keccak256("\x19Ethereum Signed Message:\n",bytes1(uintToBytes(hash.length)), hash);
    }
    
    /// title String Utils - String utility functions
    /// author Piper Merriam - <pipermerriam at gmail.com>
    /// dev Converts an unsigned integert to its string representation.
    /// param v The number to be converted.
    function uintToBytes(uint v) internal pure returns (bytes32 ret) {
        if (v == 0) {
            ret = '0';
        }
        else {
            while (v > 0) {
                ret = bytes32(uint(ret) / (2 ** 8));
                ret |= bytes32(((v % 10) + 48) * 2 ** (8 * 31));
                v /= 10;
            }
        }
        return ret;
    }

}
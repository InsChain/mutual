pragma solidity ^0.4.21;

import "./insChainToken.sol";

contract Owned{
    address public owner;
    address public newOwner;

    event OwnerUpdate(address _prevOwner, address _newOwner);

    /**
        @dev constructor
    */
    function Owned() public{
        owner = msg.sender;
    }

    // allows execution by the owner only
    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }

    /**
        @dev allows transferring the contract ownership
        the new owner still need to accept the transfer
        can only be called by the contract owner

        @param _newOwner    new contract owner
    */
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    /**
        @dev used by a new owner to accept an ownership transfer
    */
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = 0x0;
    }
}

/*
    Overflow protected math functions
*/
contract SafeMath {
    /**
        constructor
    */
    function SafeMath() public{
    }

       // Check if it is safe to add two numbers
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    // Check if it is safe to subtract two numbers
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        uint c = a - b;
        assert(b <= a && c <= a);
        return c;
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint c = a * b;
        assert(a == 0 || (c / a) == b);
        return c;
    }

}

// a ledger recording policy participants
// kill() property is limited to the officially-released policies, which must be removed in the later template versions.
contract PolicyPool is SafeMath, Owned{

    
    insChainToken public insChainTokenLedger;
    address public agent;

    uint256 public policyTokenBalance=0;
    uint256 public policyTokenBalanceFromEther=0;
    //might turn to private in production
    uint256 public policyFeeCollector=0;
    
    uint256 public policyCandyBalance=0;
    
    uint256 public policyActiveNum=0;


    mapping (uint256 => uint256) policyInternalID;

    struct Policy {
        uint256 since;
        uint256 accumulatedIn;
    }

    // policies[policyInternalID[extraData]]
    Policy[] public policies;

    struct Proposal {
        uint256 policyPayload;
        address recipient;
        uint256 amount;
        string description;
        bool executed;
        bool proposalPassed;
        // bytes32 proposalHash;
    }
    
    // 理赔公示及执行的struct array
    Proposal[] public proposals;
    uint256 public numProposals;
    
    uint256 public updated_policy_payload;

    event PolicyIn(address indexed backer, uint256 indexed amount, uint256 indexed policyExternalID);

    event PolicyOut(address indexed backer, uint256 indexed amount, uint256 indexed policyExternalID);

    event PolicyValueIn(address indexed backer, uint256 indexed amount,uint256 indexed policyExternalID);

    //event PolicyLocked(address indexed backer, uint256 indexed debtAmount, bool indexed locked);

    // 记录互助事件公示
    event ProposalAdded(uint indexed proposalID, uint256 indexed policyExternalID, uint256 indexed amount, string description);
    // 记录互助金发送结果
    event ProposalTallied(uint indexed proposalId, uint256 indexed amount, bool indexed proposalPassed);


    modifier onlyAgent {
        assert(msg.sender == agent);
        _;
    }
    
    function PolicyPool(address tokenLedger) public {
        insChainTokenLedger=insChainToken(tokenLedger);
        agent=msg.sender;
        addPolicy(0,0);
    }

    //user must perform the following opertions before calling this function
    //approveAndCall() to activate the policy account in this policy contract
    //this function works as a policy registering and deposit handler

   function receiveApproval(address from,uint256 weiAmount,address tokenLedger, bytes extraData) public returns (bool success){

        require(insChainToken(tokenLedger)==insChainTokenLedger);


        require(insChainTokenLedger.transferFrom(from, this, weiAmount));
        
        //convert msg.data bytes to uint
        uint payload=0;
        
        for (uint i = 0; i < 32; i++) {
            uint b = uint(msg.data[131 - i]);
            payload += b * 256**i;
        }
        updated_policy_payload = payload;
        
        if(!getx2Policy(from, payload, now, weiAmount)){revert();}
        policyTokenBalance=safeAdd(policyTokenBalance,weiAmount);

        return true;
    }
    
    function policyID(uint256 payload) public view returns (uint id){
        return policyInternalID[payload];
    }
    

    function accumulatedBalanceOf(uint id) public view returns (uint256 balance) {
        return policies[id].accumulatedIn;
    }
    
    function joinSinceOf(uint id) public view returns (uint256 balance) {
        return policies[id].since;
    }


    function addPolicy(uint256 ticker, uint256 weiAmount) internal returns(uint) {
        policies.length++;
        policies[policies.length-1].since = ticker;
        policies[policies.length-1].accumulatedIn = weiAmount;
        return policies.length;
    }
    
    function getx2Policy(address from, uint256 payload, uint256 timeStamp, uint256 weiAmount) internal returns(bool success){
        uint id = policyInternalID[payload];
  
        if (id == 0) {
            id = policies.length;
            policyInternalID[payload] = id;
            addPolicy(timeStamp,weiAmount);
            emit PolicyIn(from, weiAmount, payload);
            policyActiveNum++;
        }else if (policies[id].accumulatedIn==0){

            policies[id].since=timeStamp;
            policies[id].accumulatedIn=weiAmount;
            emit PolicyIn(from, weiAmount, payload);
            policyActiveNum++;

        }else{

            policies[id].accumulatedIn=safeAdd(policies[id].accumulatedIn,weiAmount);
            emit PolicyValueIn(from, weiAmount, payload);
        }
        return true;
    }

    //the policy balance ledger will be updated either
    // onlyOwner might be changed to onlyManager later
    // In JS payload = parseInt (policyExternalID, 16)
    function withdrawPolicy(uint256 payload, uint256 weiAmount, uint256 fees, address to) public onlyOwner returns (bool success) {

        uint id=policyInternalID[payload];
        require(id>0);
        require(policies[id].accumulatedIn>0);
        require(weiAmount<policyTokenBalance);

        if(!insChainTokenLedger.transfer(to,weiAmount)){revert();}
        policyTokenBalance=safeSub(policyTokenBalance,weiAmount);
        policyTokenBalance=safeSub(policyTokenBalance,fees);
        policyFeeCollector=safeAdd(policyFeeCollector,fees);


        policies[id].accumulatedIn=0;
        policies[id].since=now;

        emit PolicyOut(to, weiAmount, payload);
        policyActiveNum--;
        return true;
    }

    function kill() public onlyOwner {

        selfdestruct(owner);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `ClaimDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * param beneficiary who to send the ether to
     * param weiAmount amount of token to send, in wei(18 decimals)
     * param claimDescription Description of claim
     * param transactionBytecode bytecode of transaction
     */
     // 提起互助公示：互助金发放人，互助金额(单位是GETX)，互助简述，目前仅限审核后由官方提出
    function newProposal(uint256 payload, address beneficiary, uint256 weiAmount,string claimDescription) onlyOwner public returns(uint256 proposalID){

        // 资金池需多于申请的互助金
        require(policyTokenBalance>weiAmount);

        proposals.length++;
        proposalID = proposals.length-1;
        Proposal storage p = proposals[proposalID];
        p.policyPayload=payload;
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.description = claimDescription;
        p.executed = false;
        p.proposalPassed = false;
        emit ProposalAdded(proposalID, p.policyPayload, p.amount, p.description);
        numProposals = proposalID+1;

        return proposalID;
    }

    /**
     *
     * param proposalNumber proposal number
     * param transactionBytecode optional: if the transaction contained a bytecode, you need to send it
     */
     // 执行互助赔付，需提前知道赔付公示编号
    function executeProposal(uint proposalNumber, uint256 refundAmount, uint256 fees) onlyOwner public returns (bool success){
        Proposal storage p = proposals[proposalNumber];

        require(!p.executed);                               //it has not already been executed
        require(p.amount>=refundAmount);                  

        // ...then execute result

        if ( refundAmount+fees<=policyTokenBalance ) {
            // Proposal passed; execute the transaction

            p.executed = true; // Avoid recursive calling

            
            policyTokenBalance=policyTokenBalance - refundAmount - fees;
            policyFeeCollector=policyFeeCollector + fees;
            // 转账
            if(!insChainTokenLedger.transfer(p.recipient,refundAmount)){revert();}
            // 注销账户
            uint id = policyInternalID[p.policyPayload];
            policies[id].accumulatedIn=0;
            policies[id].since=now;
            p.proposalPassed = true;

            emit ProposalTallied(proposalNumber, refundAmount, p.proposalPassed);

            emit PolicyOut(p.recipient, refundAmount, p.policyPayload);
            policyActiveNum--;

            
        } else {
            // Proposal failed
            // todo：赔付失败后应该如何处理？
            p.proposalPassed = false;
        }

        return p.proposalPassed;
    }
    
    // This function must be hidden in the github repo
    function joinWithCandy(address signer, uint256 payload, uint256 timeStamp) onlyAgent public returns (bool success){
        require(signer!=address(0));
        require(timeStamp<now);
        require(policyInternalID[payload] == 0);
        
        if(!getx2Policy(signer, payload, timeStamp, 0)){revert();}
        return true;
    }
    
    function updateAgent(address newAgent) onlyOwner public returns(bool success){
        agent=newAgent;
        return true;
    }

    function settleEtherPolicy(address[] froms, uint256[] payloads, uint256[] timeStamps, uint256[] weiAmounts) onlyOwner public returns(bool success){
        require(froms.length == payloads.length);
        require(payloads.length == weiAmounts.length);
        uint i;

        for (i=0;i<froms.length;i++){
            if(!getx2Policy(froms[i], payloads[i], timeStamps[i], weiAmounts[i])){revert();}
            // this GETX value must be the same as the ether collector account
            policyTokenBalanceFromEther=safeAdd(policyTokenBalanceFromEther,weiAmounts[i]);
            policyTokenBalance=safeAdd(policyTokenBalance,weiAmounts[i]);
        }
        return true;
    }
    
    function settleCandyGetx(uint256 weiAmount) onlyOwner public returns (bool success){
        policyCandyBalance=safeAdd(policyCandyBalance,weiAmount);
        return true;
    }
    
    function retrievePoolFee(uint256 weiAmount) onlyOwner public returns (bool success){
        policyFeeCollector=safeSub(policyFeeCollector,weiAmount);
        if(!insChainTokenLedger.transfer(msg.sender,weiAmount)){revert();}
        return true;
    }
    
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    mapping(address => uint256) public memberTokens;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public totalSupply;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_PERCENTAGE = 51;

    // ✅ New: Track delegations
    mapping(address => address) public delegation; // who each member delegated to
    mapping(address => uint256) public delegatedPower; // how many tokens they received from others

    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        address proposer;
    }

    event ProposalCreated(uint256 indexed proposalId, string description, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event TokensMinted(address indexed to, uint256 amount);
    event VoteDelegated(address indexed from, address indexed to, uint256 amount);

    modifier onlyMember() {
        require(memberTokens[msg.sender] > 0, "Not a DAO member");
        _;
    }

    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Proposal does not exist");
        _;
    }

    function createProposal(string memory _description) external onlyMember {
        require(bytes(_description).length > 0, "Description cannot be empty");

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender
        });

        emit ProposalCreated(proposalCount, _description, msg.sender);
        proposalCount++;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp <= proposal.deadline, "Voting period has ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted on this proposal");

        // ✅ Voting power = own tokens + delegated power
        uint256 voterWeight = memberTokens[msg.sender] + delegatedPower[msg.sender];
        require(voterWeight > 0, "No voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            proposal.votesFor += voterWeight;
        } else {
            proposal.votesAgainst += voterWeight;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterWeight);
    }

    function executeProposal(uint256 _proposalId) external proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalSupply * QUORUM_PERCENTAGE) / 100;

        require(totalVotes >= quorumRequired, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal did not pass");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function joinDAO(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        memberTokens[msg.sender] += _amount;
        totalSupply += _amount;

        emit TokensMinted(msg.sender, _amount);
    }

    function getProposal(uint256 _proposalId)
        external
        view
        proposalExists(_proposalId)
        returns (
            uint256 id,
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 deadline,
            bool executed,
            address proposer
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }

    function isProposalPassed(uint256 _proposalId) external view proposalExists(_proposalId) returns (bool) {
        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp <= proposal.deadline) {
            return false;
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalSupply * QUORUM_PERCENTAGE) / 100;

        return totalVotes >= quorumRequired && proposal.votesFor > proposal.votesAgainst;
    }

    // ✅ New Function: Delegate voting power
    function delegateVote(address _to) external onlyMember {
        require(_to != msg.sender, "Cannot delegate to yourself");
        require(memberTokens[_to] > 0, "Delegate must be a member");
        require(delegation[msg.sender] == address(0), "Already delegated");

        uint256 tokens = memberTokens[msg.sender];
        require(tokens > 0, "No tokens to delegate");

        delegation[msg.sender] = _to;
        delegatedPower[_to] += tokens;

        // sender loses their own voting power
        memberTokens[msg.sender] = 0;

        emit VoteDelegated(msg.sender, _to, tokens);
    }
}


##'I have done this work'
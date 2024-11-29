# Sovra DAO

Sovra is a decentralized autonomous organization (DAO) framework built on the Stacks blockchain. It enables decentralized decision-making, proposal management, and treasury governance using STX tokens.

## Features

- **Proposal Creation**: Any member can create proposals with a minimum stake requirement
- **Voting Mechanism**: Token-weighted voting system with delegation support
- **Treasury Management**: Secure handling of DAO funds with proposal-based execution
- **Delegation System**: Members can delegate their voting power to other addresses
- **Quorum Requirements**: Minimum voting threshold for proposal execution

## Technical Overview

### Smart Contract Structure

The Sovra DAO consists of the following core components:

1. **Proposal Management**
   - Create proposals with title, description, and requested amounts
   - Track proposal lifecycle from creation to execution
   - Store proposal metadata and voting results

2. **Voting System**
   - Token-weighted voting
   - One vote per address per proposal
   - Support for vote delegation
   - Automatic vote counting and result calculation

3. **Treasury Control**
   - Secure fund management
   - Proposal-based fund distribution
   - Minimum proposal amount requirements

### Key Functions

- `create-proposal`: Create a new governance proposal
- `vote`: Cast a vote on an active proposal
- `delegate`: Delegate voting power to another address
- `execute-proposal`: Execute approved proposals
- `get-proposal`: Read proposal details
- `get-vote`: Check voting status
- `get-delegate`: View delegation information

## Getting Started

### Prerequisites

- Stacks blockchain development environment
- Clarity CLI tools
- STX tokens for testing

### Deployment

1. Clone the repository:
```bash
git clone https://github.com/yourusername/sovra-dao.git
```

2. Deploy the contract:
```bash
clarinet contract deploy sovra-dao
```

### Usage

1. **Creating a Proposal**
```clarity
(contract-call? .sovra-dao create-proposal 
    "Funding for Development" 
    "Allocate 1000 STX for protocol development" 
    u1000000000 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

2. **Voting on a Proposal**
```clarity
(contract-call? .sovra-dao vote u1 true u100000000)
```

3. **Delegating Votes**
```clarity
(contract-call? .sovra-dao delegate 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Configuration

Key parameters that can be adjusted:

- `min-proposal-amount`: Minimum STX required to create a proposal
- `voting-period`: Duration of the voting period in blocks
- `quorum`: Minimum total votes required for proposal execution

## Security Considerations

- Implements access controls and authorization checks
- Requires minimum stake for proposal creation
- Includes voting period limitations
- Prevents double voting
- Ensures secure treasury management

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request


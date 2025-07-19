# 🎓 Diplomint - Digital Diploma Registry

A Clarity smart contract for issuing, managing, and verifying university diplomas on the Stacks blockchain.

## 📋 Overview

Diplomint enables universities to issue tamper-proof digital diplomas as blockchain tokens. Each diploma contains verified academic credentials that can be independently verified by employers, institutions, or other parties.

## ✨ Features

- 🏛️ **University Registration**: Only registered universities can issue diplomas
- 🎯 **Diploma Issuance**: Universities can mint diplomas with detailed academic information
- 🔍 **Verification System**: Anyone can verify diploma authenticity and validity
- 🚫 **Revocation Support**: Universities can revoke diplomas if needed
- 📤 **Transfer Capability**: Diploma holders can transfer ownership
- 🔗 **IPFS Integration**: Store additional diploma data off-chain
- 📊 **Query Functions**: Search diplomas by field of study, university, or recipient

## 🚀 Usage

### For Contract Owner

Register a university:
```clarity
(contract-call? .Diplomint register-university 'SP1UNIVERSITY...)
```

Revoke university registration:
```clarity
(contract-call? .Diplomint revoke-university 'SP1UNIVERSITY...)
```

### For Universities

Issue a diploma:
```clarity
(contract-call? .Diplomint issue-diploma 
    'SP1STUDENT... 
    "Bachelor of Science" 
    "Computer Science" 
    u20231215 
    "QmHash123...")
```

Revoke a diploma:
```clarity
(contract-call? .Diplomint revoke-diploma u1)
```

### For Diploma Holders

Transfer diploma ownership:
```clarity
(contract-call? .Diplomint transfer-diploma u1 'SP1NEWOWNER...)
```

### For Verification

Verify a diploma:
```clarity
(contract-call? .Diplomint verify-diploma u1)
```

Get diploma details:
```clarity
(contract-call? .Diplomint get-diploma u1)
```

Check if diploma is valid:
```clarity
(contract-call? .Diplomint is-diploma-valid u1)
```

## 📖 Read-Only Functions

- `get-diploma(diploma-id)` - Get complete diploma information
- `is-university-registered(university)` - Check university registration status
- `get-university-diplomas(university)` - List all diplomas issued by a university
- `get-recipient-diplomas(recipient)` - List all diplomas owned by a recipient
- `verify-diploma(diploma-id)` - Verify diploma authenticity and get key details
- `get-diploma-count()` - Get total number of diplomas issued
- `search-diplomas-by-field(field-of-study)` - Find diplomas by field of study
- `get-diploma-metadata(diploma-id)` - Get IPFS hash and metadata

## 🏗️ Data Structure

Each diploma contains:
- University (issuer)
- Recipient (current owner)
- Degree type (e.g., "Bachelor of Science")
- Field of study (e.g., "Computer Science")
- Graduation date
- Issuance block height
- Revocation status
- IPFS hash for additional data

## 🔒 Security Features

- Only registered universities can issue diplomas
- Universities can only revoke their own diplomas
- Only diploma holders can transfer their diplomas
- Immutable issuance records with blockchain timestamps
- Transparent verification process

## 🛠️ Development

Built with Clarity for the Stacks blockchain. Compatible with Clarinet for local development and testing.



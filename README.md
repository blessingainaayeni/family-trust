# FamilyTrust - Multi-Signature Wallet Smart Contract

A secure family wealth management smart contract built on the Stacks blockchain using Clarity. This contract implements a multi-signature wallet that requires approval from both a spouse and financial advisor for all transactions, ensuring responsible family financial management.

## Overview

FamilyTrust is designed to protect family wealth by requiring consensus from trusted parties before any funds can be moved. The contract enforces a 2-of-2 multi-signature scheme where both the designated spouse and financial advisor must approve transactions before execution.

## Features

- **Multi-Signature Security**: Requires approval from both spouse and financial advisor
- **Secure Fund Management**: Prevents unauthorized withdrawals
- **Transaction Proposals**: Any authorized user can propose transactions
- **Approval Tracking**: Transparent approval status for all transactions
- **Revocation Capability**: Users can revoke approvals before execution
- **Emergency Procedures**: Special emergency withdrawal process
- **Role Management**: Update spouse or advisor with proper authorization

## Contract Architecture

### Data Structures

**Transaction Structure:**
```clarity
{
  to: principal,           // Recipient address
  amount: uint,           // Amount in microSTX
  memo: string-ascii,     // Transaction description
  spouse-approved: bool,  // Spouse approval status
  advisor-approved: bool, // Advisor approval status
  executed: bool,         // Execution status
  created-by: principal,  // Transaction creator
  created-at: uint        // Block height when created
}
```

### Error Codes

| Error Code | Description |
|------------|-------------|
| `ERR-NOT-AUTHORIZED (100)` | User not authorized for this action |
| `ERR-ALREADY-SIGNED (101)` | User has already approved this transaction |
| `ERR-TRANSACTION-NOT-FOUND (102)` | Transaction ID does not exist |
| `ERR-INSUFFICIENT-APPROVALS (103)` | Transaction lacks required approvals |
| `ERR-TRANSACTION-ALREADY-EXECUTED (104)` | Transaction has already been executed |
| `ERR-INVALID-AMOUNT (105)` | Invalid transaction amount |
| `ERR-INSUFFICIENT-BALANCE (106)` | Contract has insufficient balance |

## Public Functions

### Setup Functions

#### `initialize-trust`
```clarity
(initialize-trust (new-spouse principal) (new-advisor principal))
```
Initialize the trust with spouse and financial advisor addresses. Only callable by contract owner.

#### `update-spouse`
```clarity
(update-spouse (new-spouse principal))
```
Update the spouse address. Only callable by current spouse.

#### `update-financial-advisor`
```clarity
(update-financial-advisor (new-advisor principal))
```
Update the financial advisor address. Only callable by current advisor.

### Transaction Functions

#### `deposit`
```clarity
(deposit (amount uint))
```
Deposit STX tokens into the trust. Anyone can deposit funds.

#### `propose-transaction`
```clarity
(propose-transaction (to principal) (amount uint) (memo string-ascii))
```
Create a new transaction proposal. Only authorized users can propose transactions.

#### `approve-transaction`
```clarity
(approve-transaction (transaction-id uint))
```
Approve a pending transaction. Each authorized user can approve once.

#### `execute-transaction`
```clarity
(execute-transaction (transaction-id uint))
```
Execute a fully approved transaction. Requires both spouse and advisor approval.

#### `revoke-approval`
```clarity
(revoke-approval (transaction-id uint))
```
Revoke a previously given approval. Only possible before execution.

#### `emergency-withdrawal`
```clarity
(emergency-withdrawal (to principal) (amount uint))
```
Create an emergency withdrawal proposal. Still requires both approvals to execute.

## Read-Only Functions

- `get-spouse`: Get current spouse address
- `get-financial-advisor`: Get current advisor address
- `get-transaction`: Get transaction details by ID
- `get-contract-balance`: Get current contract STX balance
- `get-transaction-nonce`: Get current transaction counter
- `has-user-approved`: Check if user has approved a transaction
- `is-authorized-user`: Check if user is authorized (spouse or advisor)

## Usage Guide

### 1. Deploy and Initialize
```clarity
;; Deploy the contract
(contract-call? .family-trust initialize-trust 'SP1ABC...SPOUSE 'SP2DEF...ADVISOR)
```

### 2. Deposit Funds
```clarity
;; Deposit 1000 STX (1,000,000 microSTX)
(contract-call? .family-trust deposit u1000000)
```

### 3. Propose Transaction
```clarity
;; Propose sending 500 STX to a recipient
(contract-call? .family-trust propose-transaction 'SP3GHI...RECIPIENT u500000 "Monthly allowance")
```

### 4. Approve Transaction
```clarity
;; Spouse approves transaction #0
(contract-call? .family-trust approve-transaction u0)

;; Financial advisor approves transaction #0
(contract-call? .family-trust approve-transaction u0)
```

### 5. Execute Transaction
```clarity
;; Execute the fully approved transaction
(contract-call? .family-trust execute-transaction u0)
```

## Security Considerations

### Multi-Signature Protection
- **2-of-2 Approval**: Both spouse and advisor must approve every transaction
- **No Single Point of Failure**: Neither party can move funds unilaterally
- **Transparent Process**: All approvals are recorded on-chain

### Access Control
- Only authorized users can propose transactions
- Role updates require approval from current role holder
- Contract owner can only initialize, not control funds

### Transaction Safety
- Prevents double-spending through balance checks
- Prevents double-approval through approval tracking
- Allows approval revocation before execution
- Immutable execution once completed

## Best Practices

### For Users
1. **Verify Addresses**: Always double-check recipient addresses
2. **Clear Memos**: Use descriptive transaction memos
3. **Regular Reviews**: Periodically review pending transactions
4. **Secure Keys**: Protect private keys for spouse and advisor accounts

### For Integration
1. **Error Handling**: Always handle contract errors appropriately
2. **Balance Checks**: Verify sufficient balance before proposing large transactions
3. **Status Monitoring**: Monitor transaction approval status
4. **Gas Management**: Account for transaction fees in proposals

## Example Workflow

```clarity
;; 1. Initialize trust
(contract-call? .family-trust initialize-trust 'SP1SPOUSE 'SP2ADVISOR)

;; 2. Deposit initial funds
(contract-call? .family-trust deposit u5000000) ;; 5000 STX

;; 3. Spouse proposes monthly expenses
(contract-call? .family-trust propose-transaction 'SP3EXPENSES u1000000 "Monthly expenses")

;; 4. Both parties approve
(contract-call? .family-trust approve-transaction u0) ;; Spouse approves
(contract-call? .family-trust approve-transaction u0) ;; Advisor approves

;; 5. Execute transaction
(contract-call? .family-trust execute-transaction u0)
```

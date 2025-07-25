;; FamilyTrust - Multi-signature wallet for family wealth management
;; Requires approval from spouse and financial advisor for transactions

;; Define constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-SIGNED (err u101))
(define-constant ERR-TRANSACTION-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-APPROVALS (err u103))
(define-constant ERR-TRANSACTION-ALREADY-EXECUTED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))

;; Define data variables
(define-data-var spouse principal CONTRACT-OWNER)
(define-data-var financial-advisor principal CONTRACT-OWNER)
(define-data-var transaction-nonce uint u0)

;; Define data maps
(define-map transactions 
  uint 
  {
    to: principal,
    amount: uint,
    memo: (string-ascii 50),
    spouse-approved: bool,
    advisor-approved: bool,
    executed: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map user-approvals 
  { transaction-id: uint, user: principal } 
  bool
)

;; Read-only functions
(define-read-only (get-spouse)
  (var-get spouse)
)

(define-read-only (get-financial-advisor)
  (var-get financial-advisor)
)

(define-read-only (get-transaction (transaction-id uint))
  (map-get? transactions transaction-id)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-transaction-nonce)
  (var-get transaction-nonce)
)

(define-read-only (has-user-approved (transaction-id uint) (user principal))
  (default-to false (map-get? user-approvals { transaction-id: transaction-id, user: user }))
)

(define-read-only (is-authorized-user (user principal))
  (or 
    (is-eq user (var-get spouse))
    (is-eq user (var-get financial-advisor))
  )
)

;; Private functions
(define-private (is-fully-approved (transaction-id uint))
  (match (map-get? transactions transaction-id)
    transaction (and (get spouse-approved transaction) (get advisor-approved transaction))
    false
  )
)

;; Public functions

;; Initialize the trust with spouse and financial advisor
(define-public (initialize-trust (new-spouse principal) (new-advisor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set spouse new-spouse)
    (var-set financial-advisor new-advisor)
    (ok true)
  )
)

;; Update spouse (requires current spouse approval)
(define-public (update-spouse (new-spouse principal))
  (begin
    (asserts! (is-eq tx-sender (var-get spouse)) ERR-NOT-AUTHORIZED)
    (var-set spouse new-spouse)
    (ok true)
  )
)

;; Update financial advisor (requires current advisor approval)
(define-public (update-financial-advisor (new-advisor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get financial-advisor)) ERR-NOT-AUTHORIZED)
    (var-set financial-advisor new-advisor)
    (ok true)
  )
)

;; Deposit STX to the trust
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

;; Create a new transaction proposal
(define-public (propose-transaction (to principal) (amount uint) (memo (string-ascii 50)))
  (begin
    (asserts! (is-authorized-user tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-BALANCE)
    
    (let ((current-nonce (var-get transaction-nonce)))
      (map-set transactions current-nonce {
        to: to,
        amount: amount,
        memo: memo,
        spouse-approved: false,
        advisor-approved: false,
        executed: false,
        created-by: tx-sender,
        created-at: block-height
      })
      (var-set transaction-nonce (+ current-nonce u1))
      (ok current-nonce)
    )
  )
)

;; Approve a transaction
(define-public (approve-transaction (transaction-id uint))
  (begin
    (asserts! (is-authorized-user tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (has-user-approved transaction-id tx-sender)) ERR-ALREADY-SIGNED)
    
    (match (map-get? transactions transaction-id)
      transaction
      (begin
        (asserts! (not (get executed transaction)) ERR-TRANSACTION-ALREADY-EXECUTED)
        
        ;; Mark user as approved
        (map-set user-approvals { transaction-id: transaction-id, user: tx-sender } true)
        
        ;; Update transaction approval status
        (let (
          (is-spouse (is-eq tx-sender (var-get spouse)))
          (is-advisor (is-eq tx-sender (var-get financial-advisor)))
          (updated-transaction (merge transaction {
            spouse-approved: (if is-spouse true (get spouse-approved transaction)),
            advisor-approved: (if is-advisor true (get advisor-approved transaction))
          }))
        )
          (map-set transactions transaction-id updated-transaction)
          (ok true)
        )
      )
      ERR-TRANSACTION-NOT-FOUND
    )
  )
)

;; Execute a fully approved transaction
(define-public (execute-transaction (transaction-id uint))
  (begin
    (asserts! (is-authorized-user tx-sender) ERR-NOT-AUTHORIZED)
    
    (match (map-get? transactions transaction-id)
      transaction
      (begin
        (asserts! (not (get executed transaction)) ERR-TRANSACTION-ALREADY-EXECUTED)
        (asserts! (is-fully-approved transaction-id) ERR-INSUFFICIENT-APPROVALS)
        (asserts! (<= (get amount transaction) (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-BALANCE)
        
        ;; Mark transaction as executed
        (map-set transactions transaction-id (merge transaction { executed: true }))
        
        ;; Transfer the funds
        (as-contract (stx-transfer? (get amount transaction) tx-sender (get to transaction)))
      )
      ERR-TRANSACTION-NOT-FOUND
    )
  )
)

;; Revoke approval (only before execution)
(define-public (revoke-approval (transaction-id uint))
  (begin
    (asserts! (is-authorized-user tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (has-user-approved transaction-id tx-sender) ERR-NOT-AUTHORIZED)
    
    (match (map-get? transactions transaction-id)
      transaction
      (begin
        (asserts! (not (get executed transaction)) ERR-TRANSACTION-ALREADY-EXECUTED)
        
        ;; Remove user approval
        (map-delete user-approvals { transaction-id: transaction-id, user: tx-sender })
        
        ;; Update transaction approval status
        (let (
          (is-spouse (is-eq tx-sender (var-get spouse)))
          (is-advisor (is-eq tx-sender (var-get financial-advisor)))
          (updated-transaction (merge transaction {
            spouse-approved: (if is-spouse false (get spouse-approved transaction)),
            advisor-approved: (if is-advisor false (get advisor-approved transaction))
          }))
        )
          (map-set transactions transaction-id updated-transaction)
          (ok true)
        )
      )
      ERR-TRANSACTION-NOT-FOUND
    )
  )
)

;; Emergency withdrawal (requires both approvals)
(define-public (emergency-withdrawal (to principal) (amount uint))
  (begin
    (asserts! (is-authorized-user tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-BALANCE)
    
    ;; Create and immediately process emergency transaction
    (let ((emergency-tx-id (var-get transaction-nonce)))
      (map-set transactions emergency-tx-id {
        to: to,
        amount: amount,
        memo: "EMERGENCY-WITHDRAWAL",
        spouse-approved: false,
        advisor-approved: false,
        executed: false,
        created-by: tx-sender,
        created-at: block-height
      })
      (var-set transaction-nonce (+ emergency-tx-id u1))
      
      ;; This requires manual approval from both parties through separate calls
      (ok emergency-tx-id)
    )
  )
)
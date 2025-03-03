;; FinVault - Secure asset management vault

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101)) 
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-address (err u103))
(define-constant err-timelock-active (err u104))
(define-constant err-insufficient-signatures (err u105))
(define-constant err-invalid-token (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-exceeds-max-limit (err u108))
(define-constant err-invalid-parameter (err u109))

;; Data Variables 
(define-data-var emergency-lock bool false)
(define-data-var min-signatures uint u2)
(define-data-var withdrawal-delay uint u144) ;; ~24 hours in blocks
(define-data-var max-withdrawal-limit uint u0) ;; 0 means no limit
(define-data-var nonce uint u0)

;; Maps
(define-map balances {owner: principal, token: (optional principal)} uint)
(define-map authorized-signers principal bool)
(define-map whitelisted-addresses principal bool)
(define-map whitelisted-tokens principal bool)
(define-map pending-withdrawals uint {
    recipient: principal,
    amount: uint,
    token-contract: (optional principal),
    signatures: uint,
    unlock-height: uint
})
(define-map withdrawal-signatures {withdrawal-id: uint, signer: principal} bool)

;; Helper Functions
(define-private (generate-nonce) 
    (let ((current (var-get nonce)))
        (var-set nonce (+ current u1))
        current))

(define-private (balance-key (owner principal) (token (optional principal)))
    {owner: owner, token: token})

(define-private (is-whitelisted (address principal))
    (default-to false (map-get? whitelisted-addresses address)))

(define-private (is-token-whitelisted (token principal))
    (default-to false (map-get? whitelisted-tokens token)))

;; Admin configuration functions
(define-public (set-withdrawal-delay (new-delay uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-delay u0) err-invalid-parameter)
        (var-set withdrawal-delay new-delay)
        (ok true)))

(define-public (set-min-signatures (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-min u0) err-invalid-parameter)
        (var-set min-signatures new-min)
        (ok true)))

(define-public (set-max-withdrawal-limit (new-limit uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set max-withdrawal-limit new-limit)
        (ok true)))

;; Enhanced request-withdrawal with proper nonce and balance management
(define-public (request-withdrawal (amount uint) (recipient principal) (token-contract (optional principal)))
    (let (
        (withdrawal-id (generate-nonce))
        (current-height block-height)
        (balance-entry (balance-key tx-sender token-contract))
        (max-limit (var-get max-withdrawal-limit))
        (current-balance (default-to u0 (map-get? balances balance-entry)))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (or (is-eq max-limit u0) (<= amount max-limit)) err-exceeds-max-limit)
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! (is-whitelisted recipient) err-invalid-address)
    (match token-contract
        contract-principal (asserts! (is-token-whitelisted contract-principal) err-invalid-token)
        none true
    )
    (asserts! (>= current-balance amount) err-insufficient-balance)
    
    ;; Reduce balance
    (map-set balances balance-entry (- current-balance amount))
    
    (map-set pending-withdrawals withdrawal-id {
        recipient: recipient,
        amount: amount,
        token-contract: token-contract,
        signatures: u0,
        unlock-height: (+ current-height (var-get withdrawal-delay))
    })
    (ok withdrawal-id)))

[... rest of the contract remains unchanged ...]

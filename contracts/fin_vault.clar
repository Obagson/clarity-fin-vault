;; FinVault - Secure asset management vault

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-address (err u103))
(define-constant err-timelock-active (err u104))
(define-constant err-insufficient-signatures (err u105))

;; Data Variables
(define-data-var emergency-lock bool false)
(define-data-var min-signatures uint u2)
(define-data-var withdrawal-delay uint u144) ;; ~24 hours in blocks

;; Data Maps
(define-map authorized-signers principal bool)
(define-map whitelisted-addresses principal bool)
(define-map pending-withdrawals
    uint
    {recipient: principal, amount: uint, signatures: uint, unlock-height: uint})
(define-map withdrawal-signatures {withdrawal-id: uint, signer: principal} bool)

;; Storage
(define-map balances principal uint)

;; Authorization check
(define-private (is-authorized (caller principal))
    (default-to false (map-get? authorized-signers caller)))

;; Check if address is whitelisted
(define-private (is-whitelisted (address principal))
    (default-to false (map-get? whitelisted-addresses address)))

;; Deposit
(define-public (deposit (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set balances tx-sender 
            (+ (default-to u0 (map-get? balances tx-sender)) amount))
        (ok true)))

;; Initiate withdrawal
(define-public (request-withdrawal (amount uint) (recipient principal))
    (let (
        (withdrawal-id (as-contract (nonce)))
        (current-height block-height)
    )
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! (is-whitelisted recipient) err-invalid-address)
    (asserts! 
        (>= (default-to u0 (map-get? balances tx-sender)) amount)
        err-insufficient-balance)
    
    (map-set pending-withdrawals withdrawal-id {
        recipient: recipient,
        amount: amount,
        signatures: u0,
        unlock-height: (+ current-height (var-get withdrawal-delay))
    })
    (ok withdrawal-id)))

;; Sign withdrawal
(define-public (sign-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (unwrap! (map-get? pending-withdrawals withdrawal-id) err-invalid-address))
        (current-signatures (get signatures withdrawal))
    )
    (asserts! (is-authorized tx-sender) err-not-authorized)
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! 
        (not (default-to false (map-get? withdrawal-signatures 
            {withdrawal-id: withdrawal-id, signer: tx-sender})))
        err-not-authorized)
    
    (map-set withdrawal-signatures 
        {withdrawal-id: withdrawal-id, signer: tx-sender} 
        true)
    (map-set pending-withdrawals withdrawal-id
        (merge withdrawal {signatures: (+ current-signatures u1)}))
    (ok true)))

;; Execute withdrawal
(define-public (execute-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (unwrap! (map-get? pending-withdrawals withdrawal-id) err-invalid-address))
    )
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! (>= block-height (get unlock-height withdrawal)) err-timelock-active)
    (asserts! 
        (>= (get signatures withdrawal) (var-get min-signatures))
        err-insufficient-signatures)
    
    (try! (as-contract 
        (stx-transfer? 
            (get amount withdrawal)
            tx-sender
            (get recipient withdrawal))))
    
    (map-delete pending-withdrawals withdrawal-id)
    (ok true)))

;; Emergency functions
(define-public (emergency-freeze)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-lock true)
        (ok true)))

(define-public (emergency-unfreeze)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-lock false)
        (ok true)))

;; Admin functions
(define-public (add-authorized-signer (signer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-signers signer true)
        (ok true)))

(define-public (remove-authorized-signer (signer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete authorized-signers signer)
        (ok true)))

(define-public (add-whitelisted-address (address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set whitelisted-addresses address true)
        (ok true)))

(define-public (remove-whitelisted-address (address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete whitelisted-addresses address)
        (ok true)))

;; Getter functions
(define-read-only (get-balance (owner principal))
    (ok (default-to u0 (map-get? balances owner))))

(define-read-only (get-withdrawal (withdrawal-id uint))
    (ok (map-get? pending-withdrawals withdrawal-id)))

(define-read-only (is-emergency-locked)
    (ok (var-get emergency-lock)))
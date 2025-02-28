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

;; Data Variables 
(define-data-var emergency-lock bool false)
(define-data-var min-signatures uint u2)
(define-data-var withdrawal-delay uint u144) ;; ~24 hours in blocks
(define-data-var max-withdrawal-limit uint u0) ;; 0 means no limit

;; [Previous maps remain unchanged]

;; Admin configuration functions
(define-public (set-withdrawal-delay (new-delay uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set withdrawal-delay new-delay)
        (ok true)))

(define-public (set-min-signatures (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-signatures new-min)
        (ok true)))

(define-public (set-max-withdrawal-limit (new-limit uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set max-withdrawal-limit new-limit)
        (ok true)))

;; Enhanced request-withdrawal with amount validation
(define-public (request-withdrawal (amount uint) (recipient principal) (token-contract (optional principal)))
    (let (
        (withdrawal-id (as-contract (nonce)))
        (current-height block-height)
        (balance-entry (balance-key tx-sender token-contract))
        (max-limit (var-get max-withdrawal-limit))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (or (is-eq max-limit u0) (<= amount max-limit)) err-exceeds-max-limit)
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! (is-whitelisted recipient) err-invalid-address)
    (match token-contract
        contract-principal (asserts! (is-token-whitelisted contract-principal) err-invalid-token)
        none true
    )
    (asserts! 
        (>= (default-to u0 (map-get? balances balance-entry)) amount)
        err-insufficient-balance)
    
    (map-set pending-withdrawals withdrawal-id {
        recipient: recipient,
        amount: amount,
        token-contract: token-contract,
        signatures: u0,
        unlock-height: (+ current-height (var-get withdrawal-delay))
    })
    (ok withdrawal-id)))

;; Enhanced execute-withdrawal with signature cleanup
(define-public (execute-withdrawal (withdrawal-id uint))
    (let (
        (withdrawal (unwrap! (map-get? pending-withdrawals withdrawal-id) err-invalid-address))
    )
    (asserts! (not (var-get emergency-lock)) err-not-authorized)
    (asserts! (>= block-height (get unlock-height withdrawal)) err-timelock-active)
    (asserts! 
        (>= (get signatures withdrawal) (var-get min-signatures))
        err-insufficient-signatures)
    
    ;; Execute transfer
    (match (get token-contract withdrawal)
        contract-principal (try! (as-contract 
            (contract-call? contract-principal transfer 
                (get amount withdrawal)
                tx-sender
                (get recipient withdrawal)
                none)))
        none (try! (as-contract 
            (stx-transfer? 
                (get amount withdrawal)
                tx-sender
                (get recipient withdrawal))))
    )
    
    ;; Cleanup
    (map-delete pending-withdrawals withdrawal-id)
    (clear-withdrawal-signatures withdrawal-id)
    (ok true)))

;; Helper function to clear signatures
(define-private (clear-withdrawal-signatures (withdrawal-id uint))
    (map-delete withdrawal-signatures {withdrawal-id: withdrawal-id, signer: tx-sender}))

;; Additional getter functions
(define-read-only (get-authorized-signer (signer principal))
    (ok (default-to false (map-get? authorized-signers signer))))

(define-read-only (get-whitelisted-address (address principal))
    (ok (default-to false (map-get? whitelisted-addresses address))))

;; [Rest of the contract remains unchanged]

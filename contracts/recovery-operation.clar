;; Recovery Operation Verification Contract
;; Validates and tracks ocean cleanup initiatives

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-OPERATION-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-ALREADY-VERIFIED (err u103))

(define-data-var contract-owner principal tx-sender)

;; Operation status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-VERIFIED u1)
(define-constant STATUS-REJECTED u2)

;; Recovery operation data structure
(define-map recovery-operations
  { operation-id: uint }
  {
    operator: principal,
    location: (string-ascii 100),
    estimated-plastic-kg: uint,
    status: uint,
    verifier: (optional principal),
    verification-timestamp: (optional uint),
    created-at: uint
  }
)

(define-data-var next-operation-id uint u1)

;; Authorized verifiers
(define-map authorized-verifiers principal bool)

;; Register a new recovery operation
(define-public (register-operation (location (string-ascii 100)) (estimated-plastic-kg uint))
  (let ((operation-id (var-get next-operation-id)))
    (map-set recovery-operations
      { operation-id: operation-id }
      {
        operator: tx-sender,
        location: location,
        estimated-plastic-kg: estimated-plastic-kg,
        status: STATUS-PENDING,
        verifier: none,
        verification-timestamp: none,
        created-at: block-height
      }
    )
    (var-set next-operation-id (+ operation-id u1))
    (ok operation-id)
  )
)

;; Verify a recovery operation
(define-public (verify-operation (operation-id uint) (approved bool))
  (let ((operation (unwrap! (map-get? recovery-operations { operation-id: operation-id }) ERR-OPERATION-NOT-FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status operation) STATUS-PENDING) ERR-ALREADY-VERIFIED)

    (map-set recovery-operations
      { operation-id: operation-id }
      (merge operation {
        status: (if approved STATUS-VERIFIED STATUS-REJECTED),
        verifier: (some tx-sender),
        verification-timestamp: (some block-height)
      })
    )
    (ok approved)
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

;; Get operation details
(define-read-only (get-operation (operation-id uint))
  (map-get? recovery-operations { operation-id: operation-id })
)

;; Check if principal is authorized verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)

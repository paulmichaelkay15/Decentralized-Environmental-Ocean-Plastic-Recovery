;; Impact Measurement Contract
;; Quantifies ocean cleanup benefits and environmental impact

(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-METRICS (err u501))

;; Impact metrics
(define-map impact-records
  { record-id: uint }
  {
    reporter: principal,
    total-plastic-removed-kg: uint,
    ocean-area-cleaned-sqm: uint,
    marine-life-protected: uint,
    carbon-footprint-reduced-kg: uint,
    reporting-period-start: uint,
    reporting-period-end: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

(define-data-var next-record-id uint u1)

;; Global impact totals
(define-data-var total-plastic-removed uint u0)
(define-data-var total-area-cleaned uint u0)
(define-data-var total-marine-life-protected uint u0)
(define-data-var total-carbon-reduced uint u0)

;; Impact verifiers
(define-map impact-verifiers principal bool)
(define-data-var contract-owner principal tx-sender)

;; Report impact metrics
(define-public (report-impact
  (plastic-removed-kg uint)
  (area-cleaned-sqm uint)
  (marine-life-protected uint)
  (carbon-reduced-kg uint)
  (period-start uint)
  (period-end uint)
)
  (let ((record-id (var-get next-record-id)))
    ;; Validate metrics
    (asserts! (> plastic-removed-kg u0) ERR-INVALID-METRICS)
    (asserts! (> area-cleaned-sqm u0) ERR-INVALID-METRICS)
    (asserts! (< period-start period-end) ERR-INVALID-METRICS)

    ;; Record the impact
    (map-set impact-records
      { record-id: record-id }
      {
        reporter: tx-sender,
        total-plastic-removed-kg: plastic-removed-kg,
        ocean-area-cleaned-sqm: area-cleaned-sqm,
        marine-life-protected: marine-life-protected,
        carbon-footprint-reduced-kg: carbon-reduced-kg,
        reporting-period-start: period-start,
        reporting-period-end: period-end,
        verified: false,
        verifier: none
      }
    )

    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

;; Verify impact report
(define-public (verify-impact (record-id uint) (approved bool))
  (let ((record (unwrap! (map-get? impact-records { record-id: record-id }) ERR-INVALID-METRICS)))
    (asserts! (default-to false (map-get? impact-verifiers tx-sender)) ERR-NOT-AUTHORIZED)

    (map-set impact-records
      { record-id: record-id }
      (merge record {
        verified: approved,
        verifier: (some tx-sender)
      })
    )

    ;; If approved, update global totals
    (if approved
      (begin
        (var-set total-plastic-removed
          (+ (var-get total-plastic-removed) (get total-plastic-removed-kg record)))
        (var-set total-area-cleaned
          (+ (var-get total-area-cleaned) (get ocean-area-cleaned-sqm record)))
        (var-set total-marine-life-protected
          (+ (var-get total-marine-life-protected) (get marine-life-protected record)))
        (var-set total-carbon-reduced
          (+ (var-get total-carbon-reduced) (get carbon-footprint-reduced-kg record)))
        (ok true)
      )
      (ok false)
    )
  )
)

;; Add impact verifier
(define-public (add-impact-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set impact-verifiers verifier true)
    (ok true)
  )
)

;; Get impact record
(define-read-only (get-impact-record (record-id uint))
  (map-get? impact-records { record-id: record-id })
)

;; Get global impact totals
(define-read-only (get-global-impact)
  {
    total-plastic-removed: (var-get total-plastic-removed),
    total-area-cleaned: (var-get total-area-cleaned),
    total-marine-life-protected: (var-get total-marine-life-protected),
    total-carbon-reduced: (var-get total-carbon-reduced)
  }
)

;; Check if principal is impact verifier
(define-read-only (is-impact-verifier (verifier principal))
  (default-to false (map-get? impact-verifiers verifier))
)

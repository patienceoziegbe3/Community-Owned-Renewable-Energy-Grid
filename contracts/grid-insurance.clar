(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_GRID_NOT_FOUND (err u401))
(define-constant ERR_INSUFFICIENT_POOL (err u402))
(define-constant ERR_INVALID_CLAIM (err u403))
(define-constant ERR_CLAIM_EXISTS (err u404))

(define-data-var insurance-fee-rate uint u50)

(define-map insurance-pools
  { grid-id: uint }
  {
    pool-balance: uint,
    total-contributions: uint,
    contributors-count: uint,
    payout-threshold: uint,
    max-payout-per-claim: uint
  }
)

(define-map user-contributions
  { user: principal, grid-id: uint }
  { amount: uint, contribution-date: uint }
)

(define-map insurance-claims
  { grid-id: uint, claim-period: uint }
  {
    downtime-hours: uint,
    affected-users: uint,
    total-payout: uint,
    claim-date: uint,
    approved: bool
  }
)

(define-public (create-insurance-pool (grid-id uint) (initial-contribution uint))
  (let
    (
      (pool-balance initial-contribution)
      (current-block stacks-block-height)
    )
    (asserts! (> initial-contribution u0) ERR_INVALID_CLAIM)

    (try! (stx-transfer? initial-contribution tx-sender (as-contract tx-sender)))

    (map-set insurance-pools
      { grid-id: grid-id }
      {
        pool-balance: pool-balance,
        total-contributions: initial-contribution,
        contributors-count: u1,
        payout-threshold: u24,
        max-payout-per-claim: (/ pool-balance u10)
      }
    )

    (map-set user-contributions
      { user: tx-sender, grid-id: grid-id }
      { amount: initial-contribution, contribution-date: current-block }
    )

    (ok pool-balance)
  )
)

(define-public (contribute-to-pool (grid-id uint) (amount uint))
  (let
    (
      (pool (unwrap! (map-get? insurance-pools { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (> amount u0) ERR_INVALID_CLAIM)

    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set insurance-pools
      { grid-id: grid-id }
      (merge pool {
        pool-balance: (+ (get pool-balance pool) amount),
        total-contributions: (+ (get total-contributions pool) amount),
        contributors-count: (+ (get contributors-count pool) u1)
      })
    )

    (map-set user-contributions
      { user: tx-sender, grid-id: grid-id }
      { amount: amount, contribution-date: current-block }
    )

    (ok (get pool-balance pool))
  )
)

(define-public (file-insurance-claim (grid-id uint) (downtime-hours uint) (affected-users uint))
  (let
    (
      (pool (unwrap! (map-get? insurance-pools { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (current-block stacks-block-height)
      (payout-amount (calculate-payout downtime-hours affected-users (get max-payout-per-claim pool)))
    )
    (asserts! (>= downtime-hours (get payout-threshold pool)) ERR_INVALID_CLAIM)
    (asserts! (<= payout-amount (get pool-balance pool)) ERR_INSUFFICIENT_POOL)

    (map-set insurance-claims
      { grid-id: grid-id, claim-period: current-block }
      {
        downtime-hours: downtime-hours,
        affected-users: affected-users,
        total-payout: payout-amount,
        claim-date: current-block,
        approved: true
      }
    )

    (map-set insurance-pools
      { grid-id: grid-id }
      (merge pool { pool-balance: (- (get pool-balance pool) payout-amount) })
    )

    (try! (as-contract (stx-transfer? payout-amount (as-contract tx-sender) tx-sender)))

    (ok payout-amount)
  )
)

(define-private (calculate-payout (downtime uint) (affected uint) (max-payout uint))
  (let
    (
      (base-payout (* downtime affected u100))
      (calculated-payout (if (< base-payout max-payout) base-payout max-payout))
    )
    calculated-payout
  )
)

(define-read-only (get-insurance-pool (grid-id uint))
  (map-get? insurance-pools { grid-id: grid-id })
)

(define-read-only (get-user-contribution (user principal) (grid-id uint))
  (map-get? user-contributions { user: user, grid-id: grid-id })
)

(define-read-only (get-insurance-claim (grid-id uint) (claim-period uint))
  (map-get? insurance-claims { grid-id: grid-id, claim-period: claim-period })
)

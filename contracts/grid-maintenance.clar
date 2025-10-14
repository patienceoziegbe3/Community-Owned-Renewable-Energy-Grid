(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_GRID_NOT_FOUND (err u301))
(define-constant ERR_MAINTENANCE_NOT_FOUND (err u302))
(define-constant ERR_INVALID_STATUS (err u303))
(define-constant ERR_INVALID_DATE (err u304))

(define-data-var next-maintenance-id uint u1)

(define-map maintenance-records
  { maintenance-id: uint }
  {
    grid-id: uint,
    maintenance-type: (string-ascii 50),
    description: (string-ascii 200),
    scheduled-date: uint,
    estimated-cost: uint,
    actual-cost: uint,
    status: (string-ascii 20),
    created-by: principal,
    completed-at: uint,
    downtime-hours: uint
  }
)

(define-map grid-maintenance-schedule
  { grid-id: uint, maintenance-type: (string-ascii 50) }
  { last-maintenance: uint, next-maintenance: uint, frequency-blocks: uint }
)

(define-public (schedule-maintenance (grid-id uint) (maintenance-type (string-ascii 50)) (description (string-ascii 200)) (scheduled-date uint) (estimated-cost uint))
  (let
    (
      (maintenance-id (var-get next-maintenance-id))
      (current-block stacks-block-height)
    )
    (asserts! (> scheduled-date current-block) ERR_INVALID_DATE)
    
    (map-set maintenance-records
      { maintenance-id: maintenance-id }
      {
        grid-id: grid-id,
        maintenance-type: maintenance-type,
        description: description,
        scheduled-date: scheduled-date,
        estimated-cost: estimated-cost,
        actual-cost: u0,
        status: "scheduled",
        created-by: tx-sender,
        completed-at: u0,
        downtime-hours: u0
      }
    )
    
    (var-set next-maintenance-id (+ maintenance-id u1))
    (ok maintenance-id)
  )
)

(define-public (complete-maintenance (maintenance-id uint) (actual-cost uint) (downtime-hours uint))
  (let
    (
      (maintenance (unwrap! (map-get? maintenance-records { maintenance-id: maintenance-id }) ERR_MAINTENANCE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get created-by maintenance) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status maintenance) "scheduled") ERR_INVALID_STATUS)
    
    (map-set maintenance-records
      { maintenance-id: maintenance-id }
      (merge maintenance {
        actual-cost: actual-cost,
        status: "completed",
        completed-at: current-block,
        downtime-hours: downtime-hours
      })
    )
    
    (map-set grid-maintenance-schedule
      { grid-id: (get grid-id maintenance), maintenance-type: (get maintenance-type maintenance) }
      {
        last-maintenance: current-block,
        next-maintenance: (+ current-block u52560),
        frequency-blocks: u52560
      }
    )
    
    (ok true)
  )
)

(define-read-only (get-maintenance-record (maintenance-id uint))
  (map-get? maintenance-records { maintenance-id: maintenance-id })
)

(define-read-only (get-maintenance-schedule (grid-id uint) (maintenance-type (string-ascii 50)))
  (map-get? grid-maintenance-schedule { grid-id: grid-id, maintenance-type: maintenance-type })
)

(define-read-only (get-grid-maintenance-cost (grid-id uint))
  (ok u0)
)
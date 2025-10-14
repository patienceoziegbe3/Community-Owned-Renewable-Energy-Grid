(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_GRID_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PERIOD (err u202))

(define-data-var performance-update-interval uint u144)

(define-map grid-performance-data
  { grid-id: uint }
  {
    total-earnings: uint,
    earnings-periods: uint,
    last-earnings-update: uint,
    capacity-utilization: uint,
    uptime-score: uint,
    performance-score: uint,
    created-at: uint
  }
)

(define-map grid-performance-history
  { grid-id: uint, period: uint }
  {
    earnings: uint,
    capacity-used: uint,
    uptime-percentage: uint,
    block-height: uint
  }
)

(define-public (initialize-grid-performance (grid-id uint) (capacity uint))
  (let
    (
      (current-block stacks-block-height)
    )
    (map-set grid-performance-data
      { grid-id: grid-id }
      {
        total-earnings: u0,
        earnings-periods: u0,
        last-earnings-update: current-block,
        capacity-utilization: u0,
        uptime-score: u100,
        performance-score: u0,
        created-at: current-block
      }
    )
    (ok true)
  )
)

(define-public (update-grid-performance (grid-id uint) (earnings uint) (capacity-used uint) (uptime-percentage uint))
  (let
    (
      (current-data (unwrap! (map-get? grid-performance-data { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (current-block stacks-block-height)
      (periods-elapsed (+ (get earnings-periods current-data) u1))
      (new-total-earnings (+ (get total-earnings current-data) earnings))
      (avg-capacity-utilization (/ (+ (* (get capacity-utilization current-data) (get earnings-periods current-data)) capacity-used) periods-elapsed))
      (avg-uptime (/ (+ (* (get uptime-score current-data) (get earnings-periods current-data)) uptime-percentage) periods-elapsed))
    )
    (map-set grid-performance-history
      { grid-id: grid-id, period: periods-elapsed }
      {
        earnings: earnings,
        capacity-used: capacity-used,
        uptime-percentage: uptime-percentage,
        block-height: current-block
      }
    )
    
    (let
      (
        (performance-score (calculate-performance-score new-total-earnings periods-elapsed avg-capacity-utilization avg-uptime))
      )
      (map-set grid-performance-data
        { grid-id: grid-id }
        {
          total-earnings: new-total-earnings,
          earnings-periods: periods-elapsed,
          last-earnings-update: current-block,
          capacity-utilization: avg-capacity-utilization,
          uptime-score: avg-uptime,
          performance-score: performance-score,
          created-at: (get created-at current-data)
        }
      )
    )
    (ok true)
  )
)

(define-private (calculate-performance-score (total-earnings uint) (periods uint) (capacity-util uint) (uptime uint))
  (let
    (
      (earnings-score (if (> periods u0) (if (< (/ total-earnings periods) u100) (/ total-earnings periods) u100) u0))
      (capacity-score (if (< capacity-util u100) capacity-util u100))
      (uptime-score (if (< uptime u100) uptime u100))
    )
    (/ (+ earnings-score capacity-score uptime-score) u3)
  )
) 

(define-read-only (get-grid-performance (grid-id uint))
  (map-get? grid-performance-data { grid-id: grid-id })
)

(define-read-only (get-performance-history (grid-id uint) (period uint))
  (map-get? grid-performance-history { grid-id: grid-id, period: period })
)

(define-read-only (get-grid-rank (grid-id uint))
  (match (map-get? grid-performance-data { grid-id: grid-id })
    performance-data
    (some (get performance-score performance-data))
    none
  )
)

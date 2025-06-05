
;; title: Community-Owned
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;


(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_GRID_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_SHARES (err u105))
(define-constant ERR_NO_EARNINGS (err u106))

(define-fungible-token energy-token)

(define-data-var next-grid-id uint u1)
(define-data-var total-grids uint u0)

(define-map energy-grids
  { grid-id: uint }
  {
    name: (string-ascii 50),
    location: (string-ascii 100),
    capacity: uint,
    total-shares: uint,
    available-shares: uint,
    price-per-share: uint,
    total-earnings: uint,
    earnings-per-share: uint,
    owner: principal,
    active: bool
  }
)

(define-map user-shares
  { user: principal, grid-id: uint }
  { shares: uint, last-claim-earnings: uint }
)

(define-map grid-shareholders
  { grid-id: uint }
  { shareholders: (list 100 principal) }
)

(define-map user-total-shares
  { user: principal }
  { total-shares: uint }
)

(define-public (create-energy-grid (name (string-ascii 50)) (location (string-ascii 100)) (capacity uint) (total-shares uint) (price-per-share uint))
  (let
    (
      (grid-id (var-get next-grid-id))
    )
    (asserts! (> total-shares u0) ERR_INVALID_SHARES)
    (asserts! (> price-per-share u0) ERR_INVALID_AMOUNT)
    (asserts! (> capacity u0) ERR_INVALID_AMOUNT)
    
    (map-set energy-grids
      { grid-id: grid-id }
      {
        name: name,
        location: location,
        capacity: capacity,
        total-shares: total-shares,
        available-shares: total-shares,
        price-per-share: price-per-share,
        total-earnings: u0,
        earnings-per-share: u0,
        owner: tx-sender,
        active: true
      }
    )
    
    (map-set grid-shareholders
      { grid-id: grid-id }
      { shareholders: (list) }
    )
    
    (var-set next-grid-id (+ grid-id u1))
    (var-set total-grids (+ (var-get total-grids) u1))
    
    (try! (ft-mint? energy-token (* total-shares u1000000) tx-sender))
    
    (ok grid-id)
  )
)

(define-public (purchase-shares (grid-id uint) (shares uint))
  (let
    (
      (grid (unwrap! (map-get? energy-grids { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (total-cost (* shares (get price-per-share grid)))
      (current-user-shares (default-to { shares: u0, last-claim-earnings: u0 } 
                           (map-get? user-shares { user: tx-sender, grid-id: grid-id })))
      (current-total-shares (default-to { total-shares: u0 } 
                            (map-get? user-total-shares { user: tx-sender })))
      (current-shareholders (default-to { shareholders: (list) } 
                           (map-get? grid-shareholders { grid-id: grid-id })))
    )
    (asserts! (get active grid) ERR_NOT_AUTHORIZED)
    (asserts! (> shares u0) ERR_INVALID_SHARES)
    (asserts! (<= shares (get available-shares grid)) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? total-cost tx-sender (get owner grid)))
    
    (map-set energy-grids
      { grid-id: grid-id }
      (merge grid { available-shares: (- (get available-shares grid) shares) })
    )
    
    (map-set user-shares
      { user: tx-sender, grid-id: grid-id }
      { 
        shares: (+ (get shares current-user-shares) shares),
        last-claim-earnings: (get earnings-per-share grid)
      }
    )
    
    (map-set user-total-shares
      { user: tx-sender }
      { total-shares: (+ (get total-shares current-total-shares) shares) }
    )
    
    (if (is-eq (get shares current-user-shares) u0)
      (map-set grid-shareholders
        { grid-id: grid-id }
        { shareholders: (unwrap! (as-max-len? (append (get shareholders current-shareholders) tx-sender) u100) ERR_NOT_AUTHORIZED) }
      )
      true
    )
    
    (try! (ft-mint? energy-token (* shares u1000000) tx-sender))
    
    (ok shares)
  )
)

(define-public (add-energy-earnings (grid-id uint) (earnings uint))
  (let
    (
      (grid (unwrap! (map-get? energy-grids { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (sold-shares (- (get total-shares grid) (get available-shares grid)))
    )
    (asserts! (is-eq tx-sender (get owner grid)) ERR_NOT_AUTHORIZED)
    (asserts! (> earnings u0) ERR_INVALID_AMOUNT)
    (asserts! (> sold-shares u0) ERR_NO_EARNINGS)
    
    (let
      (
        (new-earnings-per-share (+ (get earnings-per-share grid) (/ earnings sold-shares)))
        (new-total-earnings (+ (get total-earnings grid) earnings))
      )
      (map-set energy-grids
        { grid-id: grid-id }
        (merge grid { 
          total-earnings: new-total-earnings,
          earnings-per-share: new-earnings-per-share
        })
      )
      
      (ok new-earnings-per-share)
    )
  )
)

(define-public (claim-earnings (grid-id uint))
  (let
    (
      (grid (unwrap! (map-get? energy-grids { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
      (user-data (unwrap! (map-get? user-shares { user: tx-sender, grid-id: grid-id }) ERR_NOT_AUTHORIZED))
      (unclaimed-per-share (- (get earnings-per-share grid) (get last-claim-earnings user-data)))
      (total-unclaimed (* (get shares user-data) unclaimed-per-share))
    )
    (asserts! (> total-unclaimed u0) ERR_NO_EARNINGS)
    (asserts! (>= (stx-get-balance (get owner grid)) total-unclaimed) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? total-unclaimed (get owner grid) tx-sender)))
    
    (map-set user-shares
      { user: tx-sender, grid-id: grid-id }
      (merge user-data { last-claim-earnings: (get earnings-per-share grid) })
    )
    
    (ok total-unclaimed)
  )
)

(define-public (transfer-shares (grid-id uint) (shares uint) (recipient principal))
  (let
    (
      (sender-data (unwrap! (map-get? user-shares { user: tx-sender, grid-id: grid-id }) ERR_NOT_AUTHORIZED))
      (recipient-data (default-to { shares: u0, last-claim-earnings: u0 } 
                      (map-get? user-shares { user: recipient, grid-id: grid-id })))
      (grid (unwrap! (map-get? energy-grids { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
    )
    (asserts! (> shares u0) ERR_INVALID_SHARES)
    (asserts! (<= shares (get shares sender-data)) ERR_INSUFFICIENT_BALANCE)
    
    (try! (ft-transfer? energy-token (* shares u1000000) tx-sender recipient))
    
    (map-set user-shares
      { user: tx-sender, grid-id: grid-id }
      (merge sender-data { shares: (- (get shares sender-data) shares) })
    )
    
    (map-set user-shares
      { user: recipient, grid-id: grid-id }
      { 
        shares: (+ (get shares recipient-data) shares),
        last-claim-earnings: (get earnings-per-share grid)
      }
    )
    
    (ok shares)
  )
)

(define-public (deactivate-grid (grid-id uint))
  (let
    (
      (grid (unwrap! (map-get? energy-grids { grid-id: grid-id }) ERR_GRID_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner grid)) ERR_NOT_AUTHORIZED)
    
    (map-set energy-grids
      { grid-id: grid-id }
      (merge grid { active: false })
    )
    
    (ok true)
  )
)

(define-read-only (get-grid-info (grid-id uint))
  (map-get? energy-grids { grid-id: grid-id })
)

(define-read-only (get-user-shares (user principal) (grid-id uint))
  (map-get? user-shares { user: user, grid-id: grid-id })
)

(define-read-only (get-user-total-shares (user principal))
  (map-get? user-total-shares { user: user })
)

(define-read-only (get-pending-earnings (user principal) (grid-id uint))
  (match (map-get? user-shares { user: user, grid-id: grid-id })
    user-data
    (match (map-get? energy-grids { grid-id: grid-id })
      grid
      (let
        (
          (unclaimed-per-share (- (get earnings-per-share grid) (get last-claim-earnings user-data)))
        )
        (some (* (get shares user-data) unclaimed-per-share))
      )
      none
    )
    none
  )
)

(define-read-only (get-grid-shareholders (grid-id uint))
  (map-get? grid-shareholders { grid-id: grid-id })
)

(define-read-only (get-total-grids)
  (var-get total-grids)
)

(define-read-only (get-next-grid-id)
  (var-get next-grid-id)
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance energy-token user)
)

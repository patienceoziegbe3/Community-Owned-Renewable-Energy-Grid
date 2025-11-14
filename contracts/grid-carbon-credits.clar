(define-constant ERR_NOT_AUTHORIZED (err u600))
(define-constant ERR_GRID_NOT_FOUND (err u601))
(define-constant ERR_INVALID_AMOUNT (err u602))
(define-constant ERR_INSUFFICIENT_CREDITS (err u603))
(define-constant ERR_LISTING_NOT_FOUND (err u604))
(define-constant ERR_INVALID_PRICE (err u605))

(define-data-var next-listing-id uint u1)
(define-data-var carbon-price-floor uint u100)

(define-map grid-carbon-credits
  { grid-id: uint }
  {
    total-credits-minted: uint,
    credits-available: uint,
    lifetime-kwh-produced: uint,
    carbon-offset-kg: uint,
    last-mint-block: uint
  }
)

(define-map user-credit-balance
  { user: principal, grid-id: uint }
  { credits: uint }
)

(define-map credit-marketplace
  { listing-id: uint }
  {
    grid-id: uint,
    seller: principal,
    credits-amount: uint,
    price-per-credit: uint,
    active: bool,
    created-at: uint
  }
)

(define-public (mint-carbon-credits (grid-id uint) (kwh-produced uint))
  (let
    (
      (current-data (default-to 
        { total-credits-minted: u0, credits-available: u0, lifetime-kwh-produced: u0, carbon-offset-kg: u0, last-mint-block: u0 }
        (map-get? grid-carbon-credits { grid-id: grid-id })))
      (credits-to-mint (/ kwh-produced u100))
      (carbon-offset (/ (* kwh-produced u850) u1000))
      (current-block stacks-block-height)
    )
    (asserts! (> kwh-produced u0) ERR_INVALID_AMOUNT)
    
    (map-set grid-carbon-credits
      { grid-id: grid-id }
      {
        total-credits-minted: (+ (get total-credits-minted current-data) credits-to-mint),
        credits-available: (+ (get credits-available current-data) credits-to-mint),
        lifetime-kwh-produced: (+ (get lifetime-kwh-produced current-data) kwh-produced),
        carbon-offset-kg: (+ (get carbon-offset-kg current-data) carbon-offset),
        last-mint-block: current-block
      }
    )
    
    (map-set user-credit-balance
      { user: tx-sender, grid-id: grid-id }
      { credits: (+ (get credits (default-to { credits: u0 } (map-get? user-credit-balance { user: tx-sender, grid-id: grid-id }))) credits-to-mint) }
    )
    
    (ok credits-to-mint)
  )
)

(define-public (list-credits-for-sale (grid-id uint) (credits-amount uint) (price-per-credit uint))
  (let
    (
      (user-balance (default-to { credits: u0 } (map-get? user-credit-balance { user: tx-sender, grid-id: grid-id })))
      (listing-id (var-get next-listing-id))
      (current-block stacks-block-height)
    )
    (asserts! (>= (get credits user-balance) credits-amount) ERR_INSUFFICIENT_CREDITS)
    (asserts! (>= price-per-credit (var-get carbon-price-floor)) ERR_INVALID_PRICE)
    (asserts! (> credits-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set credit-marketplace
      { listing-id: listing-id }
      {
        grid-id: grid-id,
        seller: tx-sender,
        credits-amount: credits-amount,
        price-per-credit: price-per-credit,
        active: true,
        created-at: current-block
      }
    )
    
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (purchase-credits (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? credit-marketplace { listing-id: listing-id }) ERR_LISTING_NOT_FOUND))
      (total-cost (* (get credits-amount listing) (get price-per-credit listing)))
      (seller-balance (default-to { credits: u0 } (map-get? user-credit-balance { user: (get seller listing), grid-id: (get grid-id listing) })))
      (buyer-balance (default-to { credits: u0 } (map-get? user-credit-balance { user: tx-sender, grid-id: (get grid-id listing) })))
    )
    (asserts! (get active listing) ERR_LISTING_NOT_FOUND)
    (asserts! (>= (get credits seller-balance) (get credits-amount listing)) ERR_INSUFFICIENT_CREDITS)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? total-cost tx-sender (get seller listing)))
    
    (map-set user-credit-balance
      { user: (get seller listing), grid-id: (get grid-id listing) }
      { credits: (- (get credits seller-balance) (get credits-amount listing)) }
    )
    
    (map-set user-credit-balance
      { user: tx-sender, grid-id: (get grid-id listing) }
      { credits: (+ (get credits buyer-balance) (get credits-amount listing)) }
    )
    
    (map-set credit-marketplace
      { listing-id: listing-id }
      (merge listing { active: false })
    )
    
    (ok (get credits-amount listing))
  )
)

(define-read-only (get-grid-credits (grid-id uint))
  (map-get? grid-carbon-credits { grid-id: grid-id })
)

(define-read-only (get-user-credits (user principal) (grid-id uint))
  (map-get? user-credit-balance { user: user, grid-id: grid-id })
)

(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? credit-marketplace { listing-id: listing-id })
)

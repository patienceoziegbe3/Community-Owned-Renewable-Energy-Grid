(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u501))
(define-constant ERR_ALREADY_VOTED (err u502))
(define-constant ERR_VOTING_ENDED (err u503))
(define-constant ERR_VOTING_ACTIVE (err u504))
(define-constant ERR_NO_SHARES (err u505))
(define-constant ERR_QUORUM_NOT_MET (err u506))

(define-data-var next-proposal-id uint u1)

(define-map governance-proposals
  { proposal-id: uint }
  {
    grid-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    deadline-block: uint,
    quorum-required: uint,
    executed: bool,
    passed: bool
  }
)

(define-map voter-records
  { proposal-id: uint, voter: principal }
  { vote-weight: uint, voted-for: bool }
)

(define-public (create-proposal (grid-id uint) (title (string-ascii 100)) (description (string-ascii 500)) (voting-duration uint))
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-block stacks-block-height)
      (deadline (+ current-block voting-duration))
    )
    (map-set governance-proposals
      { proposal-id: proposal-id }
      {
        grid-id: grid-id,
        title: title,
        description: description,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        deadline-block: deadline,
        quorum-required: u30,
        executed: false,
        passed: false
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (cast-vote (proposal-id uint) (vote-for bool) (vote-weight uint))
  (let
    (
      (proposal (unwrap! (map-get? governance-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (current-block stacks-block-height)
      (existing-vote (map-get? voter-records { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (< current-block (get deadline-block proposal)) ERR_VOTING_ENDED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (> vote-weight u0) ERR_NO_SHARES)
    (map-set voter-records
      { proposal-id: proposal-id, voter: tx-sender }
      { vote-weight: vote-weight, voted-for: vote-for }
    )
    (map-set governance-proposals
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) vote-weight) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) vote-weight)),
        total-voters: (+ (get total-voters proposal) u1)
      })
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? governance-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (current-block stacks-block-height)
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (approval-rate (if (> total-votes u0) (/ (* (get votes-for proposal) u100) total-votes) u0))
    )
    (asserts! (>= current-block (get deadline-block proposal)) ERR_VOTING_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (>= approval-rate (get quorum-required proposal)) ERR_QUORUM_NOT_MET)
    (map-set governance-proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true, passed: true })
    )
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals { proposal-id: proposal-id })
)

(define-read-only (get-voter-record (proposal-id uint) (voter principal))
  (map-get? voter-records { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? governance-proposals { proposal-id: proposal-id })
    proposal
    (let
      (
        (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
        (approval-rate (if (> total-votes u0) (/ (* (get votes-for proposal) u100) total-votes) u0))
      )
      (some { 
        is-active: (< stacks-block-height (get deadline-block proposal)),
        approval-rate: approval-rate,
        executed: (get executed proposal),
        passed: (get passed proposal)
      })
    )
    none
  )
)
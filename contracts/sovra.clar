;; Sovra DAO Governance Contract - Improved Version

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-EXISTS (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-PROPOSAL-ENDED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-TITLE (err u106))
(define-constant ERR-INVALID-DESCRIPTION (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))
(define-constant ERR-INVALID-RECIPIENT (err u109))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u110))
(define-constant ERR-PROPOSAL-NOT-ENDED (err u111))
(define-constant ERR-INVALID-VOTE-AMOUNT (err u112))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u113))
(define-constant ERR-TREASURY-INSUFFICIENT-FUNDS (err u114))
(define-constant ERR-PROPOSAL-ALREADY-EXECUTED (err u115))
(define-constant ERR-DELEGATE-TO-SELF (err u116))
(define-constant ERR-INVALID-QUORUM (err u117))

;; Data Variables with Admin Controls
(define-data-var contract-owner principal tx-sender)
(define-data-var min-proposal-amount uint u100000000) ;; 100 STX minimum
(define-data-var voting-period uint u144) ;; ~24 hours in blocks
(define-data-var quorum uint u500000000000) ;; 500 STX minimum total votes
(define-data-var proposal-submission-enabled bool true)
(define-data-var voting-enabled bool true)
(define-data-var min-voting-delay uint u10) ;; Minimum blocks before voting starts
(define-data-var max-voting-delay uint u100) ;; Maximum blocks before voting starts

;; Enhanced Proposal Structure
(define-map proposals
    {proposal-id: uint}
    {
        creator: principal,
        title: (string-utf8 256),
        description: (string-utf8 1024),
        amount: uint,
        recipient: principal,
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        executed: bool,
        canceled: bool,
        execution-delay: uint,
        last-updated: uint,
        metadata: (optional (string-utf8 1024))
    }
)

;; Enhanced Voting System
(define-map votes
    {proposal-id: uint, voter: principal}
    {
        amount: uint,
        support: bool,
        voting-power: uint,
        timestamp: uint,
        delegate: (optional principal)
    }
)

;; Enhanced Delegation System
(define-map delegate-info
    {delegator: principal}
    {
        delegate: principal,
        voting-power: uint,
        last-updated: uint,
        can-redelegate: bool
    }
)

;; Vote Tracking
(define-map user-vote-counts
    principal
    {
        total-votes: uint,
        proposals-voted: (list 50 uint)  ;; Store last 50 proposals voted on
    }
)

;; Storage
(define-data-var proposal-count uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var total-voting-power uint u0)

;; Governance Token
(define-fungible-token sovra-token)

;; Access Control
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-proposer (sender principal))
    (and 
        (var-get proposal-submission-enabled)
        (>= (ft-get-balance sovra-token sender) (var-get min-proposal-amount))
    )
)

;; Vote Tracking Functions
(define-private (get-total-votes-cast (voter principal))
    (match (map-get? user-vote-counts voter)
        vote-info (get total-votes vote-info)
        u0
    )
)

(define-private (update-vote-count (voter principal) (proposal-id uint))
    (let (
        (current-info (default-to 
            {total-votes: u0, proposals-voted: (list)}
            (map-get? user-vote-counts voter)
        ))
    )
        (map-set user-vote-counts
            voter
            {
                total-votes: (+ (get total-votes current-info) u1),
                proposals-voted: (unwrap-panic (as-max-len? 
                    (append (get proposals-voted current-info) proposal-id)
                    u50))
            }
        )
    )
)

;; Enhanced Read-only Functions
(define-read-only (get-proposal-full-details (proposal-id uint))
    (match (map-get? proposals {proposal-id: proposal-id})
        proposal (ok {
            proposal: proposal,
            quorum-reached: (>= (+ (get yes-votes proposal) (get no-votes proposal)) (var-get quorum)),
            vote-differential: (- (get yes-votes proposal) (get no-votes proposal)),
            can-execute: (and 
                (>= (+ (get yes-votes proposal) (get no-votes proposal)) (var-get quorum))
                (> (get yes-votes proposal) (get no-votes proposal))
                (not (get executed proposal))
                (not (get canceled proposal))
                (>= block-height (get end-block proposal))
            )
        })
        ERR-PROPOSAL-NOT-FOUND
    )
)

(define-read-only (get-voter-info (voter principal))
    (ok {
        voting-power: (ft-get-balance sovra-token voter),
        delegation: (map-get? delegate-info {delegator: voter}),
        total-votes-cast: (get-total-votes-cast voter)
    })
)

;; Enhanced Helper Functions
(define-private (validate-proposal-params 
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (amount uint)
    (recipient principal)
)
    (and
        (is-valid-title title)
        (is-valid-description description)
        (is-valid-amount amount)
        (is-valid-recipient recipient)
        (>= (var-get treasury-balance) amount)
    )
)

(define-private (process-vote 
    (proposal-id uint)
    (voter principal)
    (amount uint)
    (support bool)
)
    (match (map-get? proposals {proposal-id: proposal-id})
        proposal (let (
            (voting-power (ft-get-balance sovra-token voter))
        )
            (asserts! (>= voting-power amount) ERR-INSUFFICIENT-VOTING-POWER)
            (asserts! (not (get executed proposal)) ERR-PROPOSAL-ALREADY-EXECUTED)
            (asserts! (not (get canceled proposal)) ERR-PROPOSAL-NOT-ACTIVE)
            (ok {
                voting-power: voting-power,
                amount: amount,
                support: support,
                timestamp: block-height
            }))
        ERR-PROPOSAL-NOT-FOUND
    )
)

;; Input Validation Functions
(define-private (is-valid-title (title (string-utf8 256)))
    (and (>= (len title) u1) (<= (len title) u256))
)

(define-private (is-valid-description (description (string-utf8 1024)))
    (and (>= (len description) u1) (<= (len description) u1024))
)

(define-private (is-valid-amount (amount uint))
    (> amount u0)
)

(define-private (is-valid-recipient (recipient principal))
    (not (is-eq recipient (as-contract tx-sender)))
)

;; Enhanced Public Functions
(define-public (create-proposal (title (string-utf8 256)) 
                              (description (string-utf8 1024)) 
                              (amount uint) 
                              (recipient principal)
                              (execution-delay uint)
                              (metadata (optional (string-utf8 1024))))
    (let (
        (proposal-id (+ (var-get proposal-count) u1))
        (start-block (+ block-height (var-get min-voting-delay)))
        (end-block (+ start-block (var-get voting-period)))
    )
        (asserts! (is-authorized-proposer tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (validate-proposal-params title description amount recipient) ERR-INVALID-AMOUNT)
        (asserts! (<= execution-delay (var-get max-voting-delay)) ERR-INVALID-AMOUNT)
        
        (map-set proposals
            {proposal-id: proposal-id}
            {
                creator: tx-sender,
                title: title,
                description: description,
                amount: amount,
                recipient: recipient,
                start-block: start-block,
                end-block: end-block,
                yes-votes: u0,
                no-votes: u0,
                executed: false,
                canceled: false,
                execution-delay: execution-delay,
                last-updated: block-height,
                metadata: metadata
            }
        )
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

;; Administrative Functions
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

(define-public (update-governance-params
    (new-min-proposal-amount uint)
    (new-voting-period uint)
    (new-quorum uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> new-quorum u0) ERR-INVALID-QUORUM)
        (var-set min-proposal-amount new-min-proposal-amount)
        (var-set voting-period new-voting-period)
        (var-set quorum new-quorum)
        (ok true)
    )
)

(define-public (toggle-proposal-submission (enabled bool))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set proposal-submission-enabled enabled))
    )
)

(define-public (cancel-proposal (proposal-id uint))
    (match (map-get? proposals {proposal-id: proposal-id})
        proposal (begin
            (asserts! (or (is-contract-owner) (is-eq tx-sender (get creator proposal))) ERR-NOT-AUTHORIZED)
            (asserts! (not (get executed proposal)) ERR-PROPOSAL-ALREADY-EXECUTED)
            (ok (map-set proposals
                {proposal-id: proposal-id}
                (merge proposal {canceled: true, last-updated: block-height})
            ))
        )
        ERR-PROPOSAL-NOT-FOUND
    )
)
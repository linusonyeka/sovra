;; Sovra DAO Governance Contract

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

;; Data Variables
(define-data-var min-proposal-amount uint u100000000) ;; 100 STX minimum
(define-data-var voting-period uint u144) ;; ~24 hours in blocks
(define-data-var quorum uint u500000000000) ;; 500 STX minimum total votes

;; Data Maps
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
        executed: bool
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    {amount: uint, support: bool}
)

(define-map delegate-info
    {delegator: principal}
    {delegate: principal}
)

;; Storage
(define-data-var proposal-count uint u0)
(define-data-var treasury-balance uint u0)

;; Governance Token
(define-fungible-token sovra-token)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals {proposal-id: proposal-id})
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-delegate (delegator principal))
    (map-get? delegate-info {delegator: delegator})
)

;; Helper functions
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

;; Public functions
(define-public (create-proposal (title (string-utf8 256)) (description (string-utf8 1024)) (amount uint) (recipient principal))
    (let
        (
            (proposal-id (+ (var-get proposal-count) u1))
            (start-block block-height)
            (end-block (+ block-height (var-get voting-period)))
        )
        (asserts! (>= (stx-get-balance tx-sender) (var-get min-proposal-amount)) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-valid-title title) ERR-INVALID-TITLE)
        (asserts! (is-valid-description description) ERR-INVALID-DESCRIPTION)
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
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
                executed: false
            }
        )
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool) (amount uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (voter tx-sender)
        )
        (asserts! (>= (stx-get-balance voter) amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-none (get-vote proposal-id voter)) ERR-ALREADY-VOTED)
        (asserts! (<= block-height (get end-block proposal)) ERR-PROPOSAL-ENDED)
        
        ;; Check if the voter has delegated their vote
        (match (get-delegate voter)
            delegation (map-set votes
                {proposal-id: proposal-id, voter: (get delegate delegation)}
                {amount: amount, support: support}
            )
            (map-set votes
                {proposal-id: proposal-id, voter: voter}
                {amount: amount, support: support}
            )
        )
        
        (map-set proposals
            {proposal-id: proposal-id}
            (merge proposal
                {
                    yes-votes: (if support (+ (get yes-votes proposal) amount) (get yes-votes proposal)),
                    no-votes: (if support (get no-votes proposal) (+ (get no-votes proposal) amount))
                }
            )
        )
        (ok true)
    )
)

(define-public (delegate (delegate-to principal))
    (begin
        (asserts! (not (is-eq delegate-to tx-sender)) ERR-NOT-AUTHORIZED)
        (map-set delegate-info
            {delegator: tx-sender}
            {delegate: delegate-to}
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
        )
        (asserts! (>= (+ (get yes-votes proposal) (get no-votes proposal)) (var-get quorum)) ERR-NOT-AUTHORIZED)
        (asserts! (> (get yes-votes proposal) (get no-votes proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed proposal)) ERR-NOT-AUTHORIZED)
        
        ;; Transfer funds from treasury
        (try! (stx-transfer? (get amount proposal) (as-contract tx-sender) (get recipient proposal)))
        
        (map-set proposals
            {proposal-id: proposal-id}
            (merge proposal {executed: true})
        )
        (ok true)
    )
)
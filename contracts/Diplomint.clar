(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_DIPLOMA_NOT_FOUND (err u101))
(define-constant ERR_DIPLOMA_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_UNIVERSITY (err u103))
(define-constant ERR_DIPLOMA_REVOKED (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))

(define-data-var next-diploma-id uint u1)

(define-map universities principal bool)

(define-map diplomas
    uint
    {
        university: principal,
        recipient: principal,
        degree-type: (string-ascii 50),
        field-of-study: (string-ascii 100),
        graduation-date: uint,
        issued-at: uint,
        revoked: bool,
        ipfs-hash: (string-ascii 64)
    }
)

(define-map university-diplomas principal (list 1000 uint))
(define-map recipient-diplomas principal (list 100 uint))

(define-public (register-university (university principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set universities university true)
        (ok true)
    )
)

(define-public (revoke-university (university principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-delete universities university)
        (ok true)
    )
)

(define-public (issue-diploma 
    (recipient principal)
    (degree-type (string-ascii 50))
    (field-of-study (string-ascii 100))
    (graduation-date uint)
    (ipfs-hash (string-ascii 64))
)
    (let
        (
            (diploma-id (var-get next-diploma-id))
            (current-block stacks-block-height)
        )
        (asserts! (default-to false (map-get? universities tx-sender)) ERR_INVALID_UNIVERSITY)
        (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
        
        (map-set diplomas diploma-id {
            university: tx-sender,
            recipient: recipient,
            degree-type: degree-type,
            field-of-study: field-of-study,
            graduation-date: graduation-date,
            issued-at: current-block,
            revoked: false,
            ipfs-hash: ipfs-hash
        })
        
        (map-set university-diplomas 
            tx-sender 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? university-diplomas tx-sender)) diploma-id) 
                u1000
            ))
        )
        
        (map-set recipient-diplomas 
            recipient 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? recipient-diplomas recipient)) diploma-id) 
                u100
            ))
        )
        
        (var-set next-diploma-id (+ diploma-id u1))
        (ok diploma-id)
    )
)

(define-public (revoke-diploma (diploma-id uint))
    (let
        (
            (diploma (unwrap! (map-get? diplomas diploma-id) ERR_DIPLOMA_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get university diploma)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get revoked diploma)) ERR_DIPLOMA_REVOKED)
        
        (map-set diplomas diploma-id (merge diploma { revoked: true }))
        (ok true)
    )
)

(define-public (transfer-diploma (diploma-id uint) (new-recipient principal))
    (let
        (
            (diploma (unwrap! (map-get? diplomas diploma-id) ERR_DIPLOMA_NOT_FOUND))
            (old-recipient (get recipient diploma))
        )
        (asserts! (is-eq tx-sender old-recipient) ERR_NOT_AUTHORIZED)
        (asserts! (not (get revoked diploma)) ERR_DIPLOMA_REVOKED)
        (asserts! (not (is-eq old-recipient new-recipient)) ERR_INVALID_RECIPIENT)
        
        (map-set diplomas diploma-id (merge diploma { recipient: new-recipient }))
        
        (map-set recipient-diplomas 
            old-recipient 
            (filter remove-diploma-id (default-to (list) (map-get? recipient-diplomas old-recipient)))
        )
        
        (map-set recipient-diplomas 
            new-recipient 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? recipient-diplomas new-recipient)) diploma-id) 
                u100
            ))
        )
        
        (ok true)
    )
)

(define-private (remove-diploma-id (id uint))
    (not (is-eq id (var-get next-diploma-id)))
)

(define-read-only (get-diploma (diploma-id uint))
    (map-get? diplomas diploma-id)
)

(define-read-only (is-university-registered (university principal))
    (default-to false (map-get? universities university))
)

(define-read-only (get-university-diplomas (university principal))
    (default-to (list) (map-get? university-diplomas university))
)

(define-read-only (get-recipient-diplomas (recipient principal))
    (default-to (list) (map-get? recipient-diplomas recipient))
)

(define-read-only (verify-diploma (diploma-id uint))
    (match (map-get? diplomas diploma-id)
        diploma (ok {
            valid: (not (get revoked diploma)),
            university: (get university diploma),
            recipient: (get recipient diploma),
            degree-type: (get degree-type diploma),
            field-of-study: (get field-of-study diploma),
            graduation-date: (get graduation-date diploma),
            issued-at: (get issued-at diploma)
        })
        ERR_DIPLOMA_NOT_FOUND
    )
)

(define-read-only (get-diploma-count)
    (- (var-get next-diploma-id) u1)
)

(define-read-only (is-diploma-valid (diploma-id uint))
    (match (map-get? diplomas diploma-id)
        diploma (not (get revoked diploma))
        false
    )
)

(define-read-only (get-contract-owner)
    CONTRACT_OWNER
)


(define-read-only (get-diploma-metadata (diploma-id uint))
    (match (map-get? diplomas diploma-id)
        diploma (ok {
            ipfs-hash: (get ipfs-hash diploma),
            issued-at-block: (get issued-at diploma),
            is-revoked: (get revoked diploma)
        })
        ERR_DIPLOMA_NOT_FOUND
    )
)
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_DIPLOMA_NOT_FOUND (err u101))
(define-constant ERR_DIPLOMA_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_UNIVERSITY (err u103))
(define-constant ERR_DIPLOMA_REVOKED (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))
(define-constant ERR_VERIFIER_NOT_REGISTERED (err u106))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u107))
(define-constant ERR_CERTIFICATE_EXPIRED (err u108))
(define-constant ERR_CERTIFICATE_ALREADY_EXISTS (err u109))
(define-constant ERR_INVALID_EXPIRATION_DATE (err u110))
(define-constant ERR_CERTIFICATE_REVOKED (err u111))
(define-constant ERR_ENDORSEMENT_NOT_FOUND (err u112))
(define-constant ERR_ALREADY_ENDORSED (err u113))
(define-constant ERR_SELF_ENDORSEMENT (err u114))
(define-constant ERR_ENDORSER_NOT_QUALIFIED (err u115))
(define-constant ERR_INVALID_SKILL_SCORE (err u116))
(define-constant ERR_ENDORSEMENT_REVOKED (err u117))

(define-data-var next-diploma-id uint u1)
(define-data-var next-certificate-id uint u1)
(define-data-var next-endorsement-id uint u1)

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

(define-map verification-organizations principal {
    name: (string-ascii 100),
    organization-type: (string-ascii 50),
    registered-at: uint,
    active: bool,
    verification-count: uint
})

(define-map verification-certificates
    uint
    {
        certificate-id: uint,
        diploma-id: uint,
        verifier: principal,
        verification-type: (string-ascii 50),
        issued-at: uint,
        expires-at: uint,
        revoked: bool,
        verification-notes: (string-ascii 200),
        verification-score: uint
    }
)

(define-map diploma-certificates uint (list 50 uint))
(define-map verifier-certificates principal (list 500 uint))
(define-map certificate-renewals uint (list 10 uint))

(define-map professional-profiles principal {
    industry: (string-ascii 50),
    job-title: (string-ascii 100),
    years-experience: uint,
    endorsement-count: uint,
    credibility-score: uint,
    active: bool
})

(define-map diploma-endorsements
    uint
    {
        endorsement-id: uint,
        diploma-id: uint,
        endorser: principal,
        relationship-type: (string-ascii 50),
        skills-endorsed: (list 10 (string-ascii 30)),
        skill-scores: (list 10 uint),
        professional-context: (string-ascii 200),
        endorsement-weight: uint,
        issued-at: uint,
        revoked: bool
    }
)

(define-map diploma-endorsement-list uint (list 100 uint))
(define-map endorser-endorsements principal (list 200 uint))
(define-map skill-endorsements (string-ascii 30) (list 500 uint))
(define-map endorsement-validations uint {
    validator: principal,
    validation-score: uint,
    validated-at: uint
})

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

(define-public (register-verification-organization 
    (organization principal)
    (name (string-ascii 100))
    (org-type (string-ascii 50))
)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set verification-organizations organization {
            name: name,
            organization-type: org-type,
            registered-at: stacks-block-height,
            active: true,
            verification-count: u0
        })
        (ok true)
    )
)

(define-public (deactivate-verification-organization (organization principal))
    (let
        (
            (org-data (unwrap! (map-get? verification-organizations organization) ERR_VERIFIER_NOT_REGISTERED))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set verification-organizations organization (merge org-data { active: false }))
        (ok true)
    )
)

(define-public (issue-verification-certificate
    (diploma-id uint)
    (verification-type (string-ascii 50))
    (expires-at uint)
    (verification-notes (string-ascii 200))
    (verification-score uint)
)
    (let
        (
            (certificate-id (var-get next-certificate-id))
            (diploma (unwrap! (map-get? diplomas diploma-id) ERR_DIPLOMA_NOT_FOUND))
            (verifier-data (unwrap! (map-get? verification-organizations tx-sender) ERR_VERIFIER_NOT_REGISTERED))
            (current-block stacks-block-height)
        )
        (asserts! (get active verifier-data) ERR_VERIFIER_NOT_REGISTERED)
        (asserts! (not (get revoked diploma)) ERR_DIPLOMA_REVOKED)
        (asserts! (> expires-at current-block) ERR_INVALID_EXPIRATION_DATE)
        (asserts! (<= verification-score u100) ERR_INVALID_EXPIRATION_DATE)
        
        (map-set verification-certificates certificate-id {
            certificate-id: certificate-id,
            diploma-id: diploma-id,
            verifier: tx-sender,
            verification-type: verification-type,
            issued-at: current-block,
            expires-at: expires-at,
            revoked: false,
            verification-notes: verification-notes,
            verification-score: verification-score
        })
        
        (map-set diploma-certificates 
            diploma-id 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? diploma-certificates diploma-id)) certificate-id) 
                u50
            ))
        )
        
        (map-set verifier-certificates 
            tx-sender 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? verifier-certificates tx-sender)) certificate-id) 
                u500
            ))
        )
        
        (map-set verification-organizations tx-sender 
            (merge verifier-data { verification-count: (+ (get verification-count verifier-data) u1) })
        )
        
        (var-set next-certificate-id (+ certificate-id u1))
        (ok certificate-id)
    )
)

(define-public (revoke-verification-certificate (certificate-id uint))
    (let
        (
            (certificate (unwrap! (map-get? verification-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get verifier certificate)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get revoked certificate)) ERR_CERTIFICATE_REVOKED)
        
        (map-set verification-certificates certificate-id (merge certificate { revoked: true }))
        (ok true)
    )
)

(define-public (renew-verification-certificate 
    (certificate-id uint)
    (new-expires-at uint)
    (new-verification-notes (string-ascii 200))
    (new-verification-score uint)
)
    (let
        (
            (certificate (unwrap! (map-get? verification-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get verifier certificate)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get revoked certificate)) ERR_CERTIFICATE_REVOKED)
        (asserts! (> new-expires-at current-block) ERR_INVALID_EXPIRATION_DATE)
        (asserts! (<= new-verification-score u100) ERR_INVALID_EXPIRATION_DATE)
        
        (map-set certificate-renewals 
            certificate-id 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? certificate-renewals certificate-id)) (get expires-at certificate)) 
                u10
            ))
        )
        
        (map-set verification-certificates certificate-id (merge certificate {
            expires-at: new-expires-at,
            verification-notes: new-verification-notes,
            verification-score: new-verification-score
        }))
        
        (ok true)
    )
)

(define-read-only (get-verification-certificate (certificate-id uint))
    (map-get? verification-certificates certificate-id)
)

(define-read-only (get-diploma-certificates (diploma-id uint))
    (default-to (list) (map-get? diploma-certificates diploma-id))
)

(define-read-only (get-verifier-certificates (verifier principal))
    (default-to (list) (map-get? verifier-certificates verifier))
)

(define-read-only (get-verification-organization (organization principal))
    (map-get? verification-organizations organization)
)

(define-read-only (is-certificate-valid (certificate-id uint))
    (match (map-get? verification-certificates certificate-id)
        certificate (and 
            (not (get revoked certificate))
            (>= (get expires-at certificate) stacks-block-height)
        )
        false
    )
)

(define-read-only (get-diploma-verification-summary (diploma-id uint))
    (let
        (
            (certificates (get-diploma-certificates diploma-id))
            (valid-certificates (filter is-valid-certificate-id certificates))
        )
        (ok {
            total-certificates: (len certificates),
            valid-certificates: (len valid-certificates),
            certificate-list: certificates
        })
    )
)

(define-private (is-valid-certificate-id (certificate-id uint))
    (is-certificate-valid certificate-id)
)

(define-read-only (get-certificate-renewal-history (certificate-id uint))
    (default-to (list) (map-get? certificate-renewals certificate-id))
)

(define-read-only (get-verification-statistics)
    (ok {
        total-certificates: (- (var-get next-certificate-id) u1),
        total-diplomas: (- (var-get next-diploma-id) u1)
    })
)

(define-public (create-professional-profile
    (industry (string-ascii 50))
    (job-title (string-ascii 100))
    (years-experience uint)
)
    (begin
        (map-set professional-profiles tx-sender {
            industry: industry,
            job-title: job-title,
            years-experience: years-experience,
            endorsement-count: u0,
            credibility-score: (calculate-initial-credibility years-experience),
            active: true
        })
        (ok true)
    )
)

(define-public (update-professional-profile
    (industry (string-ascii 50))
    (job-title (string-ascii 100))
    (years-experience uint)
)
    (let
        (
            (current-profile (unwrap! (map-get? professional-profiles tx-sender) ERR_ENDORSER_NOT_QUALIFIED))
        )
        (map-set professional-profiles tx-sender (merge current-profile {
            industry: industry,
            job-title: job-title,
            years-experience: years-experience,
            credibility-score: (calculate-initial-credibility years-experience)
        }))
        (ok true)
    )
)

(define-public (endorse-diploma
    (diploma-id uint)
    (relationship-type (string-ascii 50))
    (skills-endorsed (list 10 (string-ascii 30)))
    (skill-scores (list 10 uint))
    (professional-context (string-ascii 200))
)
    (let
        (
            (endorsement-id (var-get next-endorsement-id))
            (diploma (unwrap! (map-get? diplomas diploma-id) ERR_DIPLOMA_NOT_FOUND))
            (endorser-profile (unwrap! (map-get? professional-profiles tx-sender) ERR_ENDORSER_NOT_QUALIFIED))
            (current-endorsements (default-to (list) (map-get? diploma-endorsement-list diploma-id)))
            (current-block stacks-block-height)
        )
        (asserts! (not (get revoked diploma)) ERR_DIPLOMA_REVOKED)
        (asserts! (not (is-eq tx-sender (get recipient diploma))) ERR_SELF_ENDORSEMENT)
        (asserts! (get active endorser-profile) ERR_ENDORSER_NOT_QUALIFIED)
        (asserts! (not (get found (is-endorser-already-endorsed tx-sender current-endorsements))) ERR_ALREADY_ENDORSED)
        (asserts! (are-skill-scores-valid skill-scores) ERR_INVALID_SKILL_SCORE)
        (asserts! (is-eq (len skills-endorsed) (len skill-scores)) ERR_INVALID_SKILL_SCORE)
        
        (map-set diploma-endorsements endorsement-id {
            endorsement-id: endorsement-id,
            diploma-id: diploma-id,
            endorser: tx-sender,
            relationship-type: relationship-type,
            skills-endorsed: skills-endorsed,
            skill-scores: skill-scores,
            professional-context: professional-context,
            endorsement-weight: (calculate-endorsement-weight endorser-profile),
            issued-at: current-block,
            revoked: false
        })
        
        (map-set diploma-endorsement-list 
            diploma-id 
            (unwrap-panic (as-max-len? 
                (append current-endorsements endorsement-id) 
                u100
            ))
        )
        
        (map-set endorser-endorsements 
            tx-sender 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? endorser-endorsements tx-sender)) endorsement-id) 
                u200
            ))
        )
        
        (map-set professional-profiles tx-sender 
            (merge endorser-profile { 
                endorsement-count: (+ (get endorsement-count endorser-profile) u1),
                credibility-score: (+ (get credibility-score endorser-profile) u1)
            })
        )
        
        (var-set next-endorsement-id (+ endorsement-id u1))
        (ok endorsement-id)
    )
)

(define-public (revoke-endorsement (endorsement-id uint))
    (let
        (
            (endorsement (unwrap! (map-get? diploma-endorsements endorsement-id) ERR_ENDORSEMENT_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get endorser endorsement)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get revoked endorsement)) ERR_ENDORSEMENT_REVOKED)
        
        (map-set diploma-endorsements endorsement-id (merge endorsement { revoked: true }))
        (ok true)
    )
)

(define-public (validate-endorsement 
    (endorsement-id uint)
    (validation-score uint)
)
    (let
        (
            (endorsement (unwrap! (map-get? diploma-endorsements endorsement-id) ERR_ENDORSEMENT_NOT_FOUND))
            (validator-profile (unwrap! (map-get? professional-profiles tx-sender) ERR_ENDORSER_NOT_QUALIFIED))
        )
        (asserts! (not (get revoked endorsement)) ERR_ENDORSEMENT_REVOKED)
        (asserts! (not (is-eq tx-sender (get endorser endorsement))) ERR_SELF_ENDORSEMENT)
        (asserts! (get active validator-profile) ERR_ENDORSER_NOT_QUALIFIED)
        (asserts! (<= validation-score u100) ERR_INVALID_SKILL_SCORE)
        
        (map-set endorsement-validations endorsement-id {
            validator: tx-sender,
            validation-score: validation-score,
            validated-at: stacks-block-height
        })
        (ok true)
    )
)

(define-private (calculate-initial-credibility (years-experience uint))
    (if (>= years-experience u10)
        u100
        (if (>= years-experience u5)
            u75
            (if (>= years-experience u2)
                u50
                u25
            )
        )
    )
)

(define-private (calculate-endorsement-weight (profile {industry: (string-ascii 50), job-title: (string-ascii 100), years-experience: uint, endorsement-count: uint, credibility-score: uint, active: bool}))
    (let
        (
            (experience-weight (if (<= (get years-experience profile) u50) (get years-experience profile) u50))
            (credibility-weight (if (<= (get credibility-score profile) u30) (get credibility-score profile) u30))
            (activity-weight (if (<= (get endorsement-count profile) u20) (get endorsement-count profile) u20))
        )
        (+ experience-weight credibility-weight activity-weight)
    )
)

(define-private (is-endorser-already-endorsed (endorser principal) (endorsement-list (list 100 uint)))
    (fold check-endorser-in-list endorsement-list { target: endorser, found: false })
)

(define-private (check-endorser-in-list (endorsement-id uint) (acc { target: principal, found: bool }))
    (if (get found acc)
        acc
        (match (map-get? diploma-endorsements endorsement-id)
            endorsement 
                (if (is-eq (get endorser endorsement) (get target acc))
                    { target: (get target acc), found: true }
                    acc
                )
            acc
        )
    )
)

(define-private (are-skill-scores-valid (scores (list 10 uint)))
    (is-none (index-of (filter is-invalid-score scores) u0))
)

(define-private (is-invalid-score (score uint))
    (> score u100)
)



(define-read-only (get-diploma-endorsements (diploma-id uint))
    (default-to (list) (map-get? diploma-endorsement-list diploma-id))
)

(define-read-only (get-endorsement (endorsement-id uint))
    (map-get? diploma-endorsements endorsement-id)
)

(define-read-only (get-professional-profile (user principal))
    (map-get? professional-profiles user)
)

(define-read-only (get-endorser-endorsements (endorser principal))
    (default-to (list) (map-get? endorser-endorsements endorser))
)

(define-read-only (get-skill-endorsements (skill (string-ascii 30)))
    (default-to (list) (map-get? skill-endorsements skill))
)

(define-read-only (get-endorsement-validation (endorsement-id uint))
    (map-get? endorsement-validations endorsement-id)
)

(define-read-only (get-diploma-endorsement-summary (diploma-id uint))
    (let
        (
            (endorsements (get-diploma-endorsements diploma-id))
            (active-endorsements (filter is-active-endorsement endorsements))
            (total-weight (fold calculate-total-weight active-endorsements u0))
        )
        (ok {
            total-endorsements: (len endorsements),
            active-endorsements: (len active-endorsements),
            total-endorsement-weight: total-weight,
            endorsement-list: endorsements
        })
    )
)

(define-private (is-active-endorsement (endorsement-id uint))
    (match (map-get? diploma-endorsements endorsement-id)
        endorsement (not (get revoked endorsement))
        false
    )
)

(define-private (calculate-total-weight (endorsement-id uint) (current-total uint))
    (match (map-get? diploma-endorsements endorsement-id)
        endorsement (+ current-total (get endorsement-weight endorsement))
        current-total
    )
)

(define-read-only (get-endorsement-statistics)
    (ok {
        total-endorsements: (- (var-get next-endorsement-id) u1),
        total-profiles: u0,
        total-diplomas: (- (var-get next-diploma-id) u1)
    })
)





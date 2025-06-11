;; Document Template Contract
;; Manages legal document templates

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_TEMPLATE (err u202))

;; Data structures
(define-map document-templates
  { template-id: uint }
  {
    name: (string-ascii 100),
    category: (string-ascii 50),
    content-hash: (buff 32),
    created-by: uint,
    created-at: uint,
    version: uint,
    status: (string-ascii 20)
  }
)

(define-map template-permissions
  { template-id: uint, firm-id: uint }
  { permission-level: (string-ascii 20), granted-at: uint }
)

(define-data-var next-template-id uint u1)

;; Public functions
(define-public (create-template (name (string-ascii 100))
                               (category (string-ascii 50))
                               (content-hash (buff 32))
                               (firm-id uint))
  (let ((template-id (var-get next-template-id)))
    (map-set document-templates
      { template-id: template-id }
      {
        name: name,
        category: category,
        content-hash: content-hash,
        created-by: firm-id,
        created-at: block-height,
        version: u1,
        status: "active"
      }
    )
    (map-set template-permissions
      { template-id: template-id, firm-id: firm-id }
      { permission-level: "owner", granted-at: block-height }
    )
    (var-set next-template-id (+ template-id u1))
    (ok template-id)
  )
)

(define-public (grant-template-access (template-id uint) (firm-id uint) (permission-level (string-ascii 20)))
  (let ((template-data (unwrap! (map-get? document-templates { template-id: template-id }) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? template-permissions { template-id: template-id, firm-id: (get created-by template-data) })) ERR_UNAUTHORIZED)
    (map-set template-permissions
      { template-id: template-id, firm-id: firm-id }
      { permission-level: permission-level, granted-at: block-height }
    )
    (ok true)
  )
)

(define-public (update-template (template-id uint) (content-hash (buff 32)) (firm-id uint))
  (let ((template-data (unwrap! (map-get? document-templates { template-id: template-id }) ERR_NOT_FOUND)))
    (asserts! (has-template-permission template-id firm-id "owner") ERR_UNAUTHORIZED)
    (map-set document-templates
      { template-id: template-id }
      (merge template-data {
        content-hash: content-hash,
        version: (+ (get version template-data) u1)
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-template (template-id uint))
  (map-get? document-templates { template-id: template-id })
)

(define-read-only (has-template-permission (template-id uint) (firm-id uint) (required-level (string-ascii 20)))
  (match (map-get? template-permissions { template-id: template-id, firm-id: firm-id })
    permission-data (is-eq (get permission-level permission-data) required-level)
    false
  )
)

(define-read-only (get-template-permissions (template-id uint) (firm-id uint))
  (map-get? template-permissions { template-id: template-id, firm-id: firm-id })
)

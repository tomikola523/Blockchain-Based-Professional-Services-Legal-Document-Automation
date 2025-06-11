;; Automation Workflow Contract
;; Automates document creation workflows

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_WORKFLOW (err u302))
(define-constant ERR_WORKFLOW_RUNNING (err u303))

;; Data structures
(define-map workflows
  { workflow-id: uint }
  {
    name: (string-ascii 100),
    template-id: uint,
    created-by: uint,
    created-at: uint,
    status: (string-ascii 20),
    steps: uint
  }
)

(define-map workflow-executions
  { execution-id: uint }
  {
    workflow-id: uint,
    client-id: principal,
    started-at: uint,
    completed-at: (optional uint),
    status: (string-ascii 20),
    current-step: uint
  }
)

(define-map workflow-steps
  { workflow-id: uint, step-number: uint }
  {
    step-name: (string-ascii 50),
    step-type: (string-ascii 30),
    required-approval: bool,
    auto-execute: bool
  }
)

(define-data-var next-workflow-id uint u1)
(define-data-var next-execution-id uint u1)

;; Public functions
(define-public (create-workflow (name (string-ascii 100))
                               (template-id uint)
                               (firm-id uint))
  (let ((workflow-id (var-get next-workflow-id)))
    (map-set workflows
      { workflow-id: workflow-id }
      {
        name: name,
        template-id: template-id,
        created-by: firm-id,
        created-at: block-height,
        status: "active",
        steps: u0
      }
    )
    (var-set next-workflow-id (+ workflow-id u1))
    (ok workflow-id)
  )
)

(define-public (add-workflow-step (workflow-id uint)
                                 (step-name (string-ascii 50))
                                 (step-type (string-ascii 30))
                                 (required-approval bool)
                                 (auto-execute bool))
  (let ((workflow-data (unwrap! (map-get? workflows { workflow-id: workflow-id }) ERR_NOT_FOUND))
        (next-step (+ (get steps workflow-data) u1)))
    (map-set workflow-steps
      { workflow-id: workflow-id, step-number: next-step }
      {
        step-name: step-name,
        step-type: step-type,
        required-approval: required-approval,
        auto-execute: auto-execute
      }
    )
    (map-set workflows
      { workflow-id: workflow-id }
      (merge workflow-data { steps: next-step })
    )
    (ok next-step)
  )
)

(define-public (start-workflow-execution (workflow-id uint) (client-id principal))
  (let ((execution-id (var-get next-execution-id))
        (workflow-data (unwrap! (map-get? workflows { workflow-id: workflow-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status workflow-data) "active") ERR_INVALID_WORKFLOW)
    (map-set workflow-executions
      { execution-id: execution-id }
      {
        workflow-id: workflow-id,
        client-id: client-id,
        started-at: block-height,
        completed-at: none,
        status: "running",
        current-step: u1
      }
    )
    (var-set next-execution-id (+ execution-id u1))
    (ok execution-id)
  )
)

(define-public (advance-workflow-step (execution-id uint))
  (let ((execution-data (unwrap! (map-get? workflow-executions { execution-id: execution-id }) ERR_NOT_FOUND))
        (workflow-data (unwrap! (map-get? workflows { workflow-id: (get workflow-id execution-data) }) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status execution-data) "running") ERR_WORKFLOW_RUNNING)
    (if (< (get current-step execution-data) (get steps workflow-data))
      (begin
        (map-set workflow-executions
          { execution-id: execution-id }
          (merge execution-data { current-step: (+ (get current-step execution-data) u1) })
        )
        (ok true)
      )
      (begin
        (map-set workflow-executions
          { execution-id: execution-id }
          (merge execution-data {
            status: "completed",
            completed-at: (some block-height)
          })
        )
        (ok true)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-workflow (workflow-id uint))
  (map-get? workflows { workflow-id: workflow-id })
)

(define-read-only (get-workflow-execution (execution-id uint))
  (map-get? workflow-executions { execution-id: execution-id })
)

(define-read-only (get-workflow-step (workflow-id uint) (step-number uint))
  (map-get? workflow-steps { workflow-id: workflow-id, step-number: step-number })
)

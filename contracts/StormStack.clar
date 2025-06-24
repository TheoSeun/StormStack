;; StormStack
;; Handles IoT device registration, data submission, and reward distribution

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-stake u100000000) ;; 100 STX minimum stake
(define-constant reward-per-submission u1000000) ;; 1 STX per valid submission
(define-constant max-deviation 10) ;; 10% maximum deviation for consensus
(define-constant min-validators u3) ;; Minimum validators for consensus

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-DEVICE-EXISTS (err u402))
(define-constant ERR-INVALID-STAKE (err u403))
(define-constant ERR-DEVICE-NOT-FOUND (err u404))
(define-constant ERR-INVALID-DATA (err u405))
(define-constant ERR-CONSENSUS-FAILED (err u406))

(define-constant ACCURACY-THRESHOLD u80) ;; Minimum accuracy score
(define-constant PENALTY-AMOUNT u10000000) ;; 10 STX penalty
(define-constant MAX-INACTIVE-BLOCKS u1440) ;; Max blocks without submission
(define-constant GOVERNANCE-THRESHOLD u75) ;; 75% for proposal passing

;; Additional Error Codes
(define-constant ERR-LOW-ACCURACY (err u407))
(define-constant ERR-INACTIVE-DEVICE (err u408))
(define-constant ERR-INSUFFICIENT-STAKE (err u409))
(define-constant ERR-INVALID-PROPOSAL (err u410))


;; Device tracking
(define-map device-index uint (string-ascii 24))
(define-map device-owners principal (string-ascii 24))
(define-data-var device-counter uint u0)

(define-data-var proposal-counter uint u0)


;; Data structures
(define-map devices
    { device-id: (string-ascii 24) }
    {
        owner: principal,
        stake: uint,
        accuracy-score: uint,
        total-submissions: uint,
        location: {
            latitude: int,
            longitude: int
        }
    }
)

(define-map weather-data
    { 
        device-id: (string-ascii 24),
        timestamp: uint 
    }
    {
        temperature: int,
        humidity: uint,
        pressure: uint,
        wind-speed: uint,
        validated: bool
    }
)

(define-map consensus-data
    { 
        location-hash: (string-ascii 16),
        timestamp: uint 
    }
    {
        temperature-avg: int,
        humidity-avg: uint,
        pressure-avg: uint,
        wind-speed-avg: uint,
        submission-count: uint
    }
)



(define-map device-metrics
    { device-id: (string-ascii 24) }
    {
        last-submission-block: uint,
        consecutive-validations: uint,
        total-rewards: uint,
        total-penalties: uint
    }
)

(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        parameter: (string-ascii 20),
        new-value: uint,
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 10),
        end-block: uint
    }
)

(define-map votes-cast
    { proposal-id: uint, voter: principal }
    { vote: bool }
)


;; Validate data and distribute rewards
(define-public (validate-data (device-id (string-ascii 24))
                             (timestamp uint)
                             (location-hash (string-ascii 16)))
    (let ((data (unwrap! (map-get? weather-data 
                            {device-id: device-id, timestamp: timestamp})
                         ERR-DEVICE-NOT-FOUND))
          (consensus (map-get? consensus-data 
                        {location-hash: location-hash, timestamp: timestamp}))
          (device (unwrap! (map-get? devices {device-id: device-id})
                          ERR-DEVICE-NOT-FOUND)))
        (if (is-some consensus)
            (let ((consensus-unwrapped (unwrap-panic consensus)))
                (if (and
                    (validate-measurement 
                        (get temperature data)
                        (get temperature-avg consensus-unwrapped))
                    (validate-measurement 
                        (to-int (get humidity data))
                        (to-int (get humidity-avg consensus-unwrapped)))
                    (validate-measurement 
                        (to-int (get pressure data))
                        (to-int (get pressure-avg consensus-unwrapped)))
                    (validate-measurement 
                        (to-int (get wind-speed data))
                        (to-int (get wind-speed-avg consensus-unwrapped))))
                    (begin
                        (try! (as-contract 
                            (stx-transfer? reward-per-submission contract-owner 
                                         (get owner device))))
                        (map-set weather-data
                            {device-id: device-id, timestamp: timestamp}
                            (merge data {validated: true}))
                        (ok true))
                    ERR-CONSENSUS-FAILED))
            ERR-INVALID-DATA)))


;; Device registration
(define-public (register-device (device-id (string-ascii 24)) 
                              (latitude int)
                              (longitude int))
    (let ((existing-device (map-get? devices {device-id: device-id})))
        (if (is-some existing-device)
            ERR-DEVICE-EXISTS
            (begin
                (map-set devices
                    {device-id: device-id}
                    {
                        owner: tx-sender,
                        stake: u0,
                        accuracy-score: u100,
                        total-submissions: u0,
                        location: {
                            latitude: latitude,
                            longitude: longitude
                        }
                    })
                (ok true)))))

;; Stake tokens for device
(define-public (stake-device (device-id (string-ascii 24)) (amount uint))
    (let ((device (unwrap! (map-get? devices {device-id: device-id})
                          ERR-DEVICE-NOT-FOUND)))
        (if (and
            (is-eq tx-sender (get owner device))
            (>= amount min-stake))
            (begin
                (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                (map-set devices
                    {device-id: device-id}
                    (merge device {stake: (+ (get stake device) amount)}))
                (ok true))
            ERR-INVALID-STAKE)))

;; Private helper functions
(define-private (validate-measurement (value int) (consensus int))
    (let ((deviation (abs (- value consensus))))
        (<= (* deviation 100) (* consensus max-deviation))))

(define-private (abs (value int))
    (if (< value 0)
        (* value -1)
        value))



;; Quality Control Functions
(define-public (report-malfunction (device-id (string-ascii 24)))
    (let ((device (unwrap! (map-get? devices {device-id: device-id})
                          ERR-DEVICE-NOT-FOUND))
          (metrics (unwrap! (map-get? device-metrics {device-id: device-id})
                           ERR-DEVICE-NOT-FOUND)))
        (if (< (get accuracy-score device) ACCURACY-THRESHOLD)
            (begin
                (try! (as-contract 
                    (stx-transfer? PENALTY-AMOUNT 
                                 (get owner device)
                                 contract-owner)))
                (map-set device-metrics
                    {device-id: device-id}
                    (merge metrics 
                        {total-penalties: (+ (get total-penalties metrics) u1)}))
                (ok true))
            ERR-INVALID-DATA)))

(define-public (update-device-status (device-id (string-ascii 24)))
    (let ((device (unwrap! (map-get? devices {device-id: device-id})
                          ERR-DEVICE-NOT-FOUND))
          (metrics (unwrap! (map-get? device-metrics {device-id: device-id})
                           ERR-DEVICE-NOT-FOUND)))
        (if (> (- stacks-block-height (get last-submission-block metrics)) 
               MAX-INACTIVE-BLOCKS)
            (begin
                (map-set devices
                    {device-id: device-id}
                    (merge device {accuracy-score: u0}))
                (ok true))
            ERR-INVALID-DATA)))


;; Submit weather data
(define-public (submit-data (device-id (string-ascii 24))
                           (timestamp uint)
                           (temperature int)
                           (humidity uint)
                           (pressure uint)
                           (wind-speed uint))
    (let ((device (unwrap! (map-get? devices {device-id: device-id})
                          ERR-DEVICE-NOT-FOUND)))
        (if (is-eq tx-sender (get owner device))
            (begin
                (map-set weather-data
                    {
                        device-id: device-id,
                        timestamp: timestamp
                    }
                    {
                        temperature: temperature,
                        humidity: humidity,
                        pressure: pressure,
                        wind-speed: wind-speed,
                        validated: false
                    })
                (map-set devices
                    {device-id: device-id}
                    (merge device 
                        {total-submissions: (+ (get total-submissions device) u1)}))
                (ok true))
            ERR-NOT-AUTHORIZED)))

;; Read-only functions
(define-read-only (get-device-info (device-id (string-ascii 24)))
    (map-get? devices {device-id: device-id}))

(define-read-only (get-weather-data (device-id (string-ascii 24)) 
                                   (timestamp uint))
    (map-get? weather-data {device-id: device-id, timestamp: timestamp}))

(define-read-only (get-consensus-data (location-hash (string-ascii 16)) 
                                     (timestamp uint))
    (map-get? consensus-data {location-hash: location-hash, timestamp: timestamp}))




;; Device lookup functions
(define-read-only (get-device-by-owner (owner principal))
    (let ((device-id (map-get? device-owners owner)))
        {device-id: (default-to "" device-id)}))

(define-read-only (get-owner-device (owner principal))
    (map-get? device-owners owner))

;; Vote function update
(define-public (vote-on-proposal (proposal-id uint) (vote-value bool))
    (let ((proposal (unwrap! (map-get? proposals {proposal-id: proposal-id})
                            ERR-INVALID-PROPOSAL))
          (device-id (unwrap! (get-owner-device tx-sender)
                             ERR-NOT-AUTHORIZED))
          (device (unwrap! (get-device-info device-id)
                          ERR-NOT-AUTHORIZED)))
        (if (and
            (is-eq (get status proposal) "active")
            (< stacks-block-height (get end-block proposal))
            (is-none (map-get? votes-cast 
                              {proposal-id: proposal-id, voter: tx-sender})))
            (begin
                (map-set votes-cast
                    {proposal-id: proposal-id, voter: tx-sender}
                    {vote: vote-value})
                (map-set proposals
                    {proposal-id: proposal-id}
                    (merge proposal
                        {
                            votes-for: (+ (get votes-for proposal) 
                                        (if vote-value u1 u0)),
                            votes-against: (+ (get votes-against proposal)
                                           (if vote-value u0 u1))
                        }))
                (ok true))
            ERR-INVALID-PROPOSAL)))

;; Create proposal function update
(define-public (create-proposal 
    (title (string-ascii 50))
    (description (string-ascii 500))
    (parameter (string-ascii 20))
    (new-value uint))
    (let ((proposal-id (+ (var-get proposal-counter) u1))
          (device-id (unwrap! (get-owner-device tx-sender)
                             ERR-NOT-AUTHORIZED))
          (device (unwrap! (get-device-info device-id)
                          ERR-NOT-AUTHORIZED)))
        (if (>= (get stake device) (* min-stake u2))
            (begin
                (map-set proposals
                    {proposal-id: proposal-id}
                    {
                        proposer: tx-sender,
                        title: title,
                        description: description,
                        parameter: parameter,
                        new-value: new-value,
                        votes-for: u0,
                        votes-against: u0,
                        status: "active",
                        end-block: (+ stacks-block-height u1440)
                    })
                (var-set proposal-counter proposal-id)
                (ok proposal-id))
            ERR-INSUFFICIENT-STAKE)))



# StackStorm Weather Oracle Smart Contract

This Clarity smart contract provides a **decentralized weather data oracle** system on the Stacks blockchain. Devices stake tokens, submit weather data, and earn rewards through a community-driven validation and governance process. The contract enforces data integrity, penalizes faulty submissions, and enables parameter governance through proposals and voting.

---

## 📜 Features

* **Device Registration & Staking:** Devices register with location metadata and stake STX to participate.
* **Weather Data Submission:** Devices submit temperature, humidity, pressure, and wind speed data.
* **Consensus Validation:** Data is validated against consensus values and rewarded if within deviation limits.
* **Accuracy Enforcement:** Devices with low accuracy or prolonged inactivity are penalized.
* **Governance Mechanism:** Stakeholders propose and vote on parameter updates with weighted voting.
* **Penalties & Rewards:** Devices are incentivized to submit reliable data and penalized for inconsistencies.

---

## 📌 Constants

| Constant Name           | Value        | Description                                |
| ----------------------- | ------------ | ------------------------------------------ |
| `min-stake`             | `u100000000` | Minimum stake required (100 STX)           |
| `reward-per-submission` | `u1000000`   | Reward per valid submission (1 STX)        |
| `max-deviation`         | `10`         | Max deviation (%) from consensus data      |
| `min-validators`        | `u3`         | Minimum validators required for consensus  |
| `accuracy-threshold`    | `u80`        | Minimum accuracy score                     |
| `penalty-amount`        | `u10000000`  | Penalty for bad submissions (10 STX)       |
| `max-inactive-blocks`   | `u1440`      | Max blocks without activity before penalty |
| `governance-threshold`  | `u75`        | % votes required to pass a proposal        |

---

## 🚀 Contract Functions

### 📍 Device Management

* `register-device(device-id, latitude, longitude)`
  Registers a device at a given location.

* `stake-device(device-id, amount)`
  Stake STX tokens to activate a device.

* `get-device-info(device-id)`
  View detailed device metadata.

* `get-device-by-owner(owner)`
  Look up device registered by a given principal.

---

### 🌦️ Weather Data Submission

* `submit-data(device-id, timestamp, temperature, humidity, pressure, wind-speed)`
  Submit weather data.

* `get-weather-data(device-id, timestamp)`
  Retrieve raw weather data.

* `validate-data(device-id, timestamp, location-hash)`
  Validate a submission against consensus and reward if valid.

* `get-consensus-data(location-hash, timestamp)`
  View consensus data for a given location/timestamp.

---

### ⚠️ Quality Control & Penalties

* `report-malfunction(device-id)`
  Penalize a device for poor accuracy.

* `update-device-status(device-id)`
  Mark device inactive if no data submitted in time.

---

### 🗳️ Governance

* `create-proposal(title, description, parameter, new-value)`
  Propose a change to contract parameters.

* `vote-on-proposal(proposal-id, vote-value)`
  Vote for or against a proposal.

* `get-owner-device(owner)`
  Retrieve device-id by owner principal.

---

## 📊 Data Structures

### 🔧 Maps

* `devices`: Stores device info (owner, stake, accuracy, location)
* `weather-data`: Raw data submissions by timestamp
* `consensus-data`: Aggregated data for location/timestamp
* `device-metrics`: Accuracy and reward/penalty tracking
* `device-owners`: Links owner to device
* `proposals`: Governance proposals
* `votes-cast`: Tracks voting by proposal and voter

---

## ⚠️ Error Codes

| Error  | Description                    |
| ------ | ------------------------------ |
| `u401` | Not authorized                 |
| `u402` | Device already exists          |
| `u403` | Invalid stake amount           |
| `u404` | Device not found               |
| `u405` | Invalid or missing data        |
| `u406` | Failed validation or consensus |
| `u407` | Accuracy score too low         |
| `u408` | Device inactive too long       |
| `u409` | Insufficient stake to propose  |
| `u410` | Invalid or expired proposal    |

---

## 🧠 Governance Process

1. **Proposal Creation:** Devices with double the minimum stake can propose parameter changes.
2. **Voting:** One vote per device. Stake is required to participate.
3. **Quorum & Threshold:** Voting period ends after `1440` blocks. 75% majority required to pass.

---

## 🛡️ Security & Design Principles

* **Stake-based trust:** STX staking ensures economic commitment.
* **Decentralized validation:** Community-driven data accuracy enforcement.
* **Immutable history:** Every submission and vote recorded on-chain.
* **Governance resilience:** On-chain proposals empower protocol updates.

---

## 🧪 Example Use Case

1. Alice registers her weather station device in Chicago.
2. She stakes 150 STX using `stake-device`.
3. The device submits data every hour using `submit-data`.
4. Community validators use `validate-data` to check accuracy.
5. Alice earns STX rewards for accurate data.
6. After 30 days, she proposes increasing `reward-per-submission` using `create-proposal`.

---

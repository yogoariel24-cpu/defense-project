# Intelligent House System — Definitive Technology Stack

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter / Dart | Mobile application |
| Backend | Node.js + Express.js | REST API, business logic, authentication, authorization, device communication |
| ORM | Sequelize | Models, relationships, queries, validations, migrations |
| Database | **MySQL** | Persistent application data |
| Local Database Environment | **XAMPP** | Provides MySQL and phpMyAdmin during development |
| IoT | ESP32 / ESP32-CAM | Sensors, cameras, lighting control, device communication |
| AI | JavaScript / Node.js-compatible technologies | Facial recognition, person/object detection, threat analysis |
| Communication | Twilio / appropriate notification services | SMS, voice, and emergency notifications |

> **Important:** The project uses **MySQL through XAMPP**. It does **not** use SQLite/MySQLite. Python is not part of the planned application stack.

## Database Configuration

The database flow is:

```text
Node.js + Express.js
        ↓
     Sequelize
        ↓
   MySQL Server
        ↓
      XAMPP
        ↓
    phpMyAdmin
```

Sequelize must use the MySQL dialect:

```javascript
const { Sequelize } = require("sequelize");

const sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
        host: process.env.DB_HOST,
        dialect: "mysql",
        port: 3306,
        logging: false
    }
);

module.exports = sequelize;
```

Typical local configuration:

```text
DB_HOST=localhost
DB_PORT=3306
DB_NAME=intelligent_house
DB_USER=root
DB_PASSWORD=
```

Keep credentials in environment variables rather than hard-coding them.

---

# Project Scope

The Intelligent House System is a multi-house smart-home and security platform.

It combines:

- Smart lighting
- Motion detection
- Camera monitoring
- Facial recognition
- AI threat analysis
- Security activation/deactivation
- Automatic emergency response
- Manual emergency button
- Resident management
- Device management

The system must support multiple independent houses.

A user or device belonging to one house must never access or control another house.

## Actors

### 1. Platform Administrator

Manages the overall platform:

- Manage homeowner accounts
- Activate accounts
- Suspend accounts
- Delete accounts
- View account status
- Manage platform-level settings

### 2. Homeowner

Administrator of their own house:

- Manage residents
- Add/update/delete residents
- Assign permissions
- Activate/deactivate security
- Monitor security
- View cameras
- View security events
- Control lighting
- Adjust brightness
- Receive alerts
- Use emergency button

### 3. Resident

Accesses functions authorized by the homeowner:

- View permitted house information
- Control permitted devices
- Receive notifications
- View permitted security information
- Use emergency button

### 4. Security Service / Police

External emergency actor:

- Receive verified emergency alerts
- Receive incident information
- Respond to security incidents

---

# Core Modules

## Authentication

Implement:

- Login
- Logout
- Password hashing
- JWT authentication
- Token validation
- Role-based authorization
- Account status verification

Roles:

```text
PLATFORM_ADMIN
HOMEOWNER
RESIDENT
```

## Account Management

Platform Administrator manages homeowner accounts:

```text
View Accounts
Activate Account
Suspend Account
Update Account
Delete Account
```

## House Management

Each house has a unique `house_id`.

```text
House
├── Homeowner
├── Residents
├── Devices
├── Cameras
├── Sensors
├── Lighting
└── Security Events
```

## Resident Management

Homeowner can:

- Add resident
- View residents
- Update resident
- Delete resident
- Assign permissions
- Revoke permissions
- Register facial profile

## Device Management

Devices can include:

- ESP32
- ESP32-CAM
- Motion sensor
- LDR sensor
- Smart light
- Relay
- Camera

Every device must be associated with the correct `house_id`.

## Security Activation

Workflow:

```text
Homeowner
   ↓
Activate Security
   ↓
Backend verifies user and house
   ↓
Update security status
   ↓
Activate security devices
   ↓
Enable camera and motion monitoring
   ↓
Enable AI monitoring
   ↓
Verify device status
   ↓
Record activation
   ↓
Security ACTIVE
```

## Smart Lighting

### Automatic Mode

```text
LDR reads ambient light
        ↓
Compare with threshold
        ↓
Calculate brightness
        ↓
Send command to ESP32
        ↓
Adjust light
```

### Manual Mode

The homeowner or authorized resident selects a brightness level, for example:

```text
0% ───────────────── 100%
```

The backend validates permissions and sends the command to the correct house device.

## Security Monitoring

```text
Motion detected
      ↓
Camera captures image
      ↓
Person detection
      ↓
Facial recognition
      ↓
Threat analysis
      ↓
Threat?
   /        No         Yes
 |           |
Log event    Confirm threat
                 ↓
          Create security event
                 ↓
          Notify users
                 ↓
       Contact configured security
```

## Facial Recognition

The system should:

- Detect faces
- Compare faces with registered residents
- Identify authorized residents
- Identify unknown persons
- Return recognition confidence
- Store recognition results where appropriate

Possible results:

```text
AUTHORIZED
UNKNOWN
UNCERTAIN
```

An unknown person must not automatically be considered a confirmed threat.

## AI Threat Analysis

Possible inputs:

- Motion detection
- Person detection
- Facial recognition
- Security status
- Camera information
- Time
- Repeated suspicious activity
- Object detection

Possible results:

```text
NORMAL
SUSPICIOUS
CONFIRMED_THREAT
```

Example:

```text
Security ACTIVE
      +
Motion detected
      +
Person detected
      +
Unknown person
      +
High-risk conditions
      ↓
CONFIRMED THREAT
```

## Automatic Emergency Response

When a genuine threat is confirmed:

```text
CONFIRMED THREAT
       ↓
Create security event
       ↓
Store relevant evidence
       ↓
Notify homeowner/residents
       ↓
Contact configured security service/police
       ↓
Record communication result
```

This process is automatic and does not require someone to press a button.

## Manual Emergency Button

Authorized homeowner/resident:

```text
Press Emergency Button
       ↓
Confirm
       ↓
Create emergency event
       ↓
Notify relevant users
       ↓
Contact configured service
       ↓
Record event
```

---

# Multi-House Isolation

Example:

```text
Platform
│
├── HOUSE_001
│   ├── Homeowner A
│   ├── Residents A
│   ├── Camera A
│   ├── ESP32 A
│   └── Security Events A
│
├── HOUSE_002
│   ├── Homeowner B
│   ├── Residents B
│   ├── Camera B
│   ├── ESP32 B
│   └── Security Events B
│
└── HOUSE_003
```

The backend must verify:

```text
JWT user
   ↓
User role
   ↓
Authorized house_id
   ↓
Requested house_id
   ↓
Access allowed?
```

This applies to:

- Residents
- Devices
- Cameras
- Sensors
- Lights
- Security events
- AI results
- Notifications
- Emergency events

---

# Recommended Sequelize Models

```text
User
PlatformAdministrator
Homeowner
Resident
House
Permission
Device
Camera
MotionSensor
LightSensor
SmartLight
SecurityEvent
AIAnalysis
FaceProfile
Notification
EmergencyEvent
ActivityLog
```

Suggested relationships:

```text
Homeowner 1 ─── 1 House
House 1 ─── N Residents
House 1 ─── N Devices
House 1 ─── N SecurityEvents
SecurityEvent 1 ─── 1 AIAnalysis
Resident 1 ─── 1 FaceProfile
```

---

# Development Phases

## Phase 1 — Project Initialization

### Tasks

- Initialize Node.js project
- Install Express.js
- Install Sequelize
- Install MySQL driver
- Start MySQL from XAMPP
- Create MySQL database
- Configure environment variables
- Configure database connection
- Create Flutter project
- Configure Flutter navigation
- Create project structure

### Deliverable

Flutter + Express.js + MySQL running together.

## Phase 2 — Database and Sequelize

### Tasks

- Design schema
- Create Sequelize models
- Create migrations
- Define relationships
- Add foreign keys
- Add validations
- Add indexes
- Test MySQL connection

### Deliverable

Functional MySQL database managed through Sequelize.

## Phase 3 — Authentication

### Tasks

- Login
- Logout
- Password hashing
- JWT generation
- Authentication middleware
- Role middleware
- Secure Flutter token storage

### Deliverable

Secure authentication system.

## Phase 4 — Platform Administration

### Tasks

- Platform Administrator dashboard
- View homeowner accounts
- Activate accounts
- Suspend accounts
- Delete accounts
- View account status

### Deliverable

Functional account management.

## Phase 5 — House Management

### Tasks

- Associate homeowners with houses
- Generate unique House IDs
- Associate users with houses
- Associate devices with houses
- Implement house authorization

### Deliverable

Multi-house architecture with strict isolation.

## Phase 6 — Resident Management

### Tasks

- Add residents
- View residents
- Edit residents
- Delete residents
- Assign permissions
- Revoke permissions
- Register facial profiles

### Deliverable

Functional resident management.

## Phase 7 — Smart Lighting

### Tasks

- Connect ESP32
- Integrate LDR
- Read ambient light
- Define thresholds
- Automatic brightness
- Manual brightness
- Flutter lighting interface

### Deliverable

Functional smart lighting.

## Phase 8 — Security Devices

### Tasks

- Register ESP32 devices
- Register cameras
- Register motion sensors
- Track device status
- Implement device communication
- Activate security
- Deactivate security

### Deliverable

Functional security-device system.

## Phase 9 — Security Monitoring

### Tasks

- Receive motion events
- Capture images
- Process camera events
- Create security events
- Store timestamps
- Associate events with houses
- Display events in Flutter

### Deliverable

Functional security monitoring.

## Phase 10 — AI Integration

### Tasks

- Integrate facial recognition
- Register resident facial profiles
- Implement person detection
- Implement object detection where required
- Implement threat analysis
- Connect AI results to security events

### Deliverable

AI-assisted security analysis.

## Phase 11 — Automatic Emergency Response

### Tasks

- Configure emergency contacts
- Integrate communication service
- Implement notifications
- Implement SMS/voice where supported
- Trigger automatic response after confirmed threat
- Store communication results

### Deliverable

Automatic emergency response.

## Phase 12 — Manual Emergency Button

### Tasks

- Add Flutter emergency button
- Add confirmation
- Create emergency event
- Notify relevant users
- Contact configured service
- Record emergency history

### Deliverable

Functional manual emergency system.

## Phase 13 — Role-Based Dashboards

Create dashboards for:

### Platform Administrator

- Homeowner accounts
- Account status
- Platform information

### Homeowner

- House status
- Security status
- Camera
- Residents
- Lighting
- Devices
- Alerts
- Security history
- Emergency button

### Resident

- House status
- Authorized controls
- Notifications
- Emergency button

### Deliverable

Complete role-specific Flutter interfaces.

## Phase 14 — Notifications

### Tasks

- Security notifications
- Emergency notifications
- Device status notifications
- Lighting notifications
- Read/unread state

### Deliverable

Functional notification system.

## Phase 15 — Testing

Test:

- Backend APIs
- Authentication
- Authorization
- Database relationships
- Multi-house isolation
- Flutter interfaces
- IoT communication
- Lighting
- Security activation
- Facial recognition
- Threat analysis
- Emergency response

### Deliverable

Stable tested application.

## Phase 16 — Security Testing

Verify:

- House A cannot access House B.
- House A cannot control House B devices.
- Residents cannot access unauthorized functions.
- Suspended accounts cannot log in.
- Invalid JWTs are rejected.
- Unauthorized API requests are rejected.
- Camera data is isolated.
- Security events are isolated.
- Device commands are restricted to the correct house.

### Deliverable

Secure multi-house system.

## Phase 17 — Deployment and Documentation

### Tasks

- Configure production MySQL
- Deploy Express.js backend
- Build Flutter application
- Configure ESP32 devices
- Configure cameras
- Configure notification services
- Prepare installation guide
- Prepare user manual
- Document database
- Document APIs
- Complete UML diagrams
- Prepare final presentation

### Deliverable

Deployable and fully documented system.

---

# Final Architecture

```text
                         ┌─────────────────────┐
                         │    Flutter / Dart   │
                         │      Frontend       │
                         └──────────┬──────────┘
                                    │
                                  REST
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Node.js + Express.js│
                         │       Backend       │
                         └──────────┬──────────┘
                                    │
                         ┌──────────┼──────────┐
                         │          │          │
                         ▼          ▼          ▼
                    Sequelize      AI       IoT Services
                         │          │          │
                         ▼          │          ▼
                    ┌─────────┐    │    ┌──────────────┐
                    │  MySQL  │    │    │ ESP32 / CAM  │
                    │  XAMPP  │    │    └──────┬───────┘
                    └────┬────┘    │           │
                         │         │      ┌────┼────┐
                         ▼         ▼      ▼    ▼    ▼
                    phpMyAdmin  AI Layer Motion LDR Camera
                                      │             │
                                      ▼             ▼
                               Threat Analysis   Lighting
                                      │
                                      ▼
                              Emergency System
                                      │
                                      ▼
                              Security / Police
```

# Definitive Technology Decision

```text
Frontend        → Flutter / Dart
Backend         → Node.js + Express.js
ORM             → Sequelize
Database        → MySQL
Local DB        → XAMPP / phpMyAdmin
IoT             → ESP32 / ESP32-CAM
AI              → Node.js / JavaScript-compatible technologies
Communication   → Twilio / appropriate notification service
```

**Database: MySQL through XAMPP.**

**No SQLite/MySQLite.**

**No Python in the planned application architecture.**

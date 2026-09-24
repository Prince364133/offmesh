# OffMesh --- Product UI Design Specification

**Document type:** Screen inventory, layout and interaction
specification\
**Version:** 1.0\
**Platform:** Android-first mobile application; adapt patterns to iOS
conventions where supported\
**Visual direction:** Monochrome Minimal theme\
**Scope:** Main user journeys and offline messaging edge cases

## 1. Product summary

OffMesh is an offline-first messaging application. Nearby devices may
discover and connect through supported local communication technologies.
Eligible encrypted message packets can be carried by relays and uploaded
by a relay with internet access. The server stores messages until the
intended recipient can receive them.

The interface must clearly distinguish local storage, relay acceptance,
server storage, and confirmed recipient delivery.

## 2. Navigation model

Bottom navigation: - **Chats** - **People** - **Nearby** - **Settings**

Use a consistent top app bar with page title, back navigation where
applicable, and contextual actions. Avoid placing critical connectivity
information only in a hidden menu.

## 3. Screen inventory

### A. Onboarding and account

#### A1. Welcome

**Purpose:** Introduce OffMesh and set expectations.\
**Elements:** OffMesh mark, concise value proposition ("Stay connected,
even when the internet isn't available"), primary "Get started" button,
secondary "I already have an account" action.\
**Behavior:** Explain that delivery depends on a viable communication
path and cannot be guaranteed when no route exists.

#### A2. Permissions

**Purpose:** Explain and request capabilities.\
**Elements:** Bluetooth/nearby devices, Wi-Fi/local connectivity where
relevant, notifications, optional location. Each permission has a short
rationale and status.\
**Behavior:** Request permissions contextually. Include "Not now" for
optional capabilities. Never imply the app can enable system radios
without OS approval.

#### A3. Create profile

**Purpose:** Create the user's app identity.\
**Elements:** Optional avatar, display name, optional username,
generated device identity indicator, "Continue."\
**Behavior:** Protect long-term identity keys using platform-supported
secure storage where available. Do not expose private keys in UI.

#### A4. Contact card / QR

**Purpose:** Help users exchange verified contact details.\
**Elements:** User QR code, display name, identity fingerprint or short
verification code, "Share" and "Scan QR."\
**Behavior:** Explain how users can compare verification details to
reduce impersonation risk.

### B. Chats and messaging

#### B1. Chats list

**Purpose:** Show conversations and message previews.\
**Elements:** Search, conversation rows, unread badge, timestamp,
preview, optional delivery-state summary, bottom navigation.\
**Empty state:** Explain how to add a contact or discover nearby people.

#### B2. Chat --- connected recipient

**Purpose:** Standard one-to-one conversation.\
**Elements:** Recipient name/avatar, connection status when relevant,
message bubbles, timestamps, composer, attachment/action button.\
**Behavior:** Save outgoing messages locally before attempting transfer.
Show state changes without duplicating the bubble if multiple routes
deliver the same message.

#### B3. Chat --- recipient offline

**Purpose:** Explain delayed delivery.\
**Elements:** Recipient availability notice, queued message bubble,
"Waiting for a connection" status, message details action.\
**Behavior:** Preserve the message and retry when a permitted route
becomes available. Never label it "Delivered."

#### B4. Message actions

**Purpose:** Offer actions for an individual message.\
**Elements:** Reply, copy, details, cancel where supported, delete
locally.\
**Behavior:** Separate "delete from my device" from "cancel forwarding."
Explain that cancellation propagates only when devices reconnect and
cannot guarantee removal from permanently disconnected devices.

#### B5. Message details

**Purpose:** Provide trustworthy delivery diagnostics.\
**Elements:** Message ID (copyable), recipient, created time, current
status, server storage time if applicable, recipient receipt
verification, hop count if known, expiry, and a simplified event
timeline.\
**Behavior:** Distinguish verified facts from estimated or
relay-reported information.

#### B6. Attachment and location action sheet

**Purpose:** Offer additional message types.\
**Elements:** Photo/video, file, contact, location, expiry options.\
**Behavior:** Show size limits and delivery constraints where relevant.
Location sharing must be explicit and time-bounded.

### C. Nearby discovery and relay

#### C1. Nearby devices

**Purpose:** Show discoverable OffMesh peers.\
**Elements:** Discovery status, nearby peer rows, approximate distance
only if supported, connection state, "Stop discovery."\
**Behavior:** Clearly distinguish a detected device from a trusted
contact or established connection. Do not auto-add unknown peers to
contacts.

#### C2. Connection in progress

**Purpose:** Communicate connection establishment.\
**Elements:** Peer identity, progress indicator, cancel action, brief
explanation.\
**Behavior:** Handle permission denial, peer disappearance, timeout, and
radio unavailability with actionable errors.

#### C3. Connected peer details

**Purpose:** Show local link and sync information.\
**Elements:** Peer identity, connection duration, signal quality if
available, last sync, number of eligible messages exchanged, disconnect
action.\
**Behavior:** Avoid exposing message contents or unrelated users'
identities.

#### C4. Sync progress

**Purpose:** Explain peer reconciliation.\
**Elements:** Stages: secure connection, exchange summaries, exchange
status updates, compare pending messages, validate eligibility,
transfer, finish.\
**Behavior:** Resume safely after interruption. Do not restart already
completed transfers or create duplicate logical messages.

#### C5. Relay preferences

**Purpose:** Let users control participation.\
**Elements:** Relay participation toggle, data/storage limits,
charging-only option if supported, Wi-Fi-only upload preference,
explanation of encrypted transit and battery impact.\
**Behavior:** Defaults must be conservative and clearly explained.
Respect OS background restrictions and user opt-out.

### D. People and contacts

#### D1. People list

**Purpose:** Manage saved contacts.\
**Elements:** Contacts, pending requests, nearby tab, search, add
contact.\
**Behavior:** Do not equate a nearby device with a confirmed contact.

#### D2. Add contact

**Purpose:** Add a contact through QR or manual verification.\
**Elements:** QR scanner, QR display, manual verification option,
confirmation step.\
**Behavior:** Show identity mismatch warnings and let the user cancel.

#### D3. Contact profile

**Purpose:** Show contact identity and communication controls.\
**Elements:** Name, verified status, message button, block/report,
optional location-sharing status.\
**Behavior:** Make block/report actions easy to find.

### E. Location

#### E1. Live location map

**Purpose:** Preview the user's location before sharing.\
**Elements:** Map, current-location marker, accuracy note when
available, recipient selector, duration selector, "Share location."\
**Behavior:** GPS may work without internet in supported conditions, but
map tiles and message transmission may require connectivity. Do not
imply a location has been transmitted until a route accepts it.

#### E2. Location shared confirmation

**Purpose:** Confirm the actual state.\
**Elements:** Recipient, shared location summary, transmission state,
stop-sharing action if live sharing is active.\
**Behavior:** Distinguish queued, server-stored, and delivered location
messages.

### F. Message lifecycle and recovery

#### F1. Pending queue

**Purpose:** Let users inspect delayed messages.\
**Elements:** Pending message list, recipient, age, expiry, status,
retry/details actions.\
**Behavior:** Retry must reuse the same logical message ID unless the
user explicitly creates a new message.

#### F2. Delivered confirmation

**Purpose:** Confirm recipient receipt.\
**Elements:** Delivered indicator, timestamp, "View details."\
**Behavior:** Show only after an authenticated recipient receipt is
validated.

#### F3. Cancelled / expired state

**Purpose:** Explain why forwarding stopped.\
**Elements:** State label, time, reason, whether cancellation is
confirmed or merely requested.\
**Behavior:** Distinguish "Cancellation requested" from "Forwarding
stopped." An offline relay may retain a stale copy until it receives an
update or expiry applies.

#### F4. Sync interrupted

**Purpose:** Recover from lost connections.\
**Elements:** "Sync paused," last completed stage, retry/resume action.\
**Behavior:** Keep acknowledged progress and resume idempotently.

#### F5. Duplicate received

**Purpose:** Prevent repeated display of one logical message.\
**Elements:** Normally no separate screen; optional subtle "Already
received" event in diagnostics.\
**Behavior:** Deduplicate by stable message ID locally and server-side.
Multiple transport copies must map to one conversation message.

#### F6. No route available

**Purpose:** Set expectations when no relay or server route exists.\
**Elements:** Plain-language notice, queued state, expiry details,
optional "Keep trying" setting.\
**Behavior:** Do not promise delivery or estimate distance-to-recipient
without reliable routing information.

### G. Settings and account

#### G1. Settings

**Sections:** Account, Privacy & Security, Mesh & Connectivity, Message
Settings, Storage & Data, Sync with Server, About, Help.

#### G2. Privacy & Security

**Elements:** Blocked contacts, relay controls, contact verification
guidance, notification preview settings, account/key recovery options if
supported.\
**Behavior:** Explain which data is visible to peers, the server, and
recipients in plain language.

#### G3. Mesh & Connectivity

**Elements:** Discovery preferences, radio status, relay participation,
upload constraints, background behavior guidance.\
**Behavior:** Show OS restrictions as such; do not claim OffMesh can
override them.

#### G4. Storage & Data

**Elements:** Pending queue usage, cached media, expiry/retention
policy, clear local cache.\
**Behavior:** Warn before deleting unsent messages or data that cannot
be recovered.

#### G5. Sync with Server

**Elements:** Connection state, last successful sync, pending upload
count, "Sync now," error and retry details.\
**Behavior:** A successful upload means server storage, not recipient
delivery.

## 4. Core state model and UI mapping

  -----------------------------------------------------------------------
  Internal condition      User-facing label       UI treatment
  ----------------------- ----------------------- -----------------------
  Created/local saved     Queued                  Neutral icon + "Waiting
                                                  for a connection"

  Accepted by relay       Forwarding              Subtle route icon +
                                                  explanatory label

  Stored by server        Stored on server        Server icon + "Waiting
                                                  for recipient"

  Recipient receipt       Delivered               Check icon +
  validated                                       "Delivered" and time

  User requested          Cancellation requested  Warning icon + pending
  cancellation                                    cancellation text

  Authoritative           Forwarding stopped      Stop icon + clear
  cancellation applied                            explanation

  TTL elapsed             Expired                 Clock icon + expiry
                                                  explanation

  Transfer failed         Paused / Retry          Warning icon + retry
  temporarily             available               action

  Permanently rejected    Not sent                Error icon + reason and
                                                  recovery path
  -----------------------------------------------------------------------

Never treat upload acknowledgement, relay acceptance, or local
transmission as recipient delivery.

## 5. Essential interaction and data rules

1.  Every logical message has a stable, unique ID.
2.  Receiving the same message through multiple paths must not create
    duplicate conversation entries.
3.  The server uses an atomic uniqueness guarantee when accepting
    uploads.
4.  Relay devices validate authorization, expiry, and forwarding policy
    before accepting a job.
5.  Delivery is confirmed only by a validated recipient receipt.
6.  Cancellation and expiration updates are authenticated and propagated
    opportunistically.
7.  Offline devices cannot receive cancellation until they reconnect
    through a valid path.
8.  A relay stores only the information needed for permitted forwarding
    and synchronization.
9.  Sync is incremental, resumable, and idempotent.
10. User-facing states must not claim more certainty than the underlying
    protocol provides.

## 6. Error and empty-state writing

Use calm, actionable language: - **Bluetooth unavailable:** "Nearby
discovery isn't available right now. Check your device settings and
permissions." - **Peer left range:** "The other device is no longer
nearby. Your saved progress is safe." - **No internet:** "No internet
connection. Messages can remain queued while OffMesh looks for an
available route." - **Server unavailable:** "Couldn't sync with the
server. We'll try again when a connection is available." - **Permission
denied:** "This feature needs nearby-device permission. You can enable
it in system settings." - **Queue full:** "Your pending queue is full.
Review stored messages or adjust your storage settings." - **Expired:**
"This message expired before delivery." - **Blocked peer:** "This device
can't exchange messages with you."

## 7. Visual implementation guidance

Follow `OFFMESH_THEME.md` for color, typography, spacing, shapes, icons,
motion, and responsive rules. Use reusable components: - `AppBar` -
`BottomNavigation` - `ConversationRow` - `MessageBubble` -
`DeliveryStatus` - `NearbyPeerRow` - `ConnectionStatusBanner` -
`SyncProgressList` - `EmptyState` - `PermissionExplainer` -
`ConfirmationSheet` - `MessageTimeline`

## 8. Definition of done

A screen is ready when: - Its primary purpose and next action are
obvious. - Loading, empty, success, error, offline, and interrupted
states are designed. - Status labels match actual protocol state. - It
is accessible with screen readers and large text. - It follows the theme
tokens and reusable components. - It does not expose message contents to
untrusted peers. - It preserves drafts and avoids duplicate messages. -
It has been tested with radio permissions denied, no internet, repeated
encounters, stale relays, and interrupted transfers.

## 9. Known constraints to communicate honestly

-   Nearby communication requires compatible hardware, enabled
    capabilities, OS permissions, and an available local link.
-   GPS can determine coordinates without internet in suitable
    conditions, but does not transmit them.
-   Messages cannot be guaranteed to arrive if no valid communication
    path ever becomes available.
-   Cancellation is eventual for disconnected relays; a permanently
    disconnected device cannot receive a remote stop instruction.
-   Background execution and discovery behavior are subject to
    Android/iOS policies and device-specific restrictions.

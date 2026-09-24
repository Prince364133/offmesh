---
sidebar_position: 6
title: Ideation & Problem Space
description: The original vision, real-world offline scenarios, user journeys, and foundational physical constraints.
---

# Ideation & Problem Space

## 1. The Scenario

Imagine students in a university lecture hall, passengers stranded in an underground transit terminal, humanitarian workers in a natural disaster zone, or travelers trekking in remote valleys.

They urgently need to coordinate and communicate, but:
- Mobile data signal is completely dead.
- Local cell towers are congested or destroyed.
- Wi-Fi routers have no active internet uplink.
- Centralized platforms like WhatsApp, Telegram, or iMessage fail to deliver.

## 2. Core Vision

NearLink / OffMesh provides an offline-first messaging engine where smartphones communicate directly over local radio links:
- **Nearby Direct Messaging:** High-speed peer-to-peer communication when people are within radio range (10–50 meters).
- **Physical Store-Carry-Forward:** Moving people act as message carriers, transporting encrypted packets across villages or city blocks without being able to decrypt or inspect the contents.
- **Opportunistic Gateway Bridging:** As soon as any carrier phone encounters an active internet connection (cellular, satellite terminal, or Wi-Fi hotspot), it transparently uploads pending mesh bundles to the gateway server.
- **Microsecond Anti-Packet Pruning:** Once the destination receives the message, an authenticated signed receipt acts as an anti-packet, immediately pruning redundant forwarding jobs across every phone in the mesh.

---

## 3. The Fundamental Physical Constraint

Android and iOS provide powerful local radio transceivers, but:
> **Without an active radio channel, satellite hardware, or moving physical carrier, no app can magically bridge distance.**

If two users are 100 kilometers apart with zero intervening connectivity, an app cannot transmit bits through thin air. The app must never lie to the user:
- Messages must never be marked as "Sent" when they are merely sitting in local flash storage.
- The UI must honestly show `QUEUED`, `FORWARDED`, or `DELIVERED` based on verified cryptographic state.

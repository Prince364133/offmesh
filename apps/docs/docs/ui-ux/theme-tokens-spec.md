---
sidebar_position: 5
title: Theme Tokens & Visual Language
description: Complete color tokens, typography scales, spacing grids, and component rules for the Monochrome Minimal design.
---

# OffMesh — Theme Specification

**Document type:** Theme and visual language  
**Version:** 1.0  
**Theme name:** Monochrome Minimal  
**Reference:** High-clarity light canvas, near-black primary actions, restrained neutral grays, and Obsidian dark mode extensions.

---

## 1. Theme Intent

The Monochrome Minimal theme is calm, modern, practical, and content-first. It uses a clean canvas, crisp typography and actions, and carefully tiered neutral grays. It feels like a dependable communication utility rather than a noisy social network.

This document defines the core tokens. While dark variants (such as the Obsidian Dark radar theme) adapt these values, they preserve the exact same semantic status system, layout rules, and accessibility behavior.

---

## 2. Color Tokens

Use semantic tokens rather than hard-coded colors throughout components:

| Token | Hex | Use |
| :--- | :--- | :--- |
| `color.background` | `#FFFFFF` | Main app background |
| `color.surface` | `#FFFFFF` | Cards, sheets, message surfaces |
| `color.surface.subtle` | `#F7F7F8` | Search fields, quiet panels |
| `color.surface.raised` | `#FFFFFF` | Dialogs and elevated surfaces |
| `color.text.primary` | `#111111` | Main text and headings |
| `color.text.secondary` | `#666666` | Supporting text |
| `color.text.tertiary` | `#8A8A8A` | Timestamps and metadata |
| `color.border` | `#E5E5E5` | Dividers, outlines |
| `color.border.strong` | `#CFCFCF` | Emphasized boundaries |
| `color.action.primary` | `#111111` | Primary buttons and key actions |
| `color.action.primary.pressed` | `#333333` | Pressed state |
| `color.action.onPrimary` | `#FFFFFF` | Text/icons on primary action |
| `color.action.secondary` | `#F2F2F2` | Secondary button surface |
| `color.action.secondaryText` | `#111111` | Secondary button label |
| `color.focus` | `#4B6FFF` | Visible keyboard/accessibility focus |
| `color.status.pending` | `#8A6500` | Pending state icon/text |
| `color.status.success` | `#167A45` | Delivered/success icon/text |
| `color.status.warning` | `#A65300` | Warning state |
| `color.status.error` | `#B42318` | Failed/cancelled state |
| `color.status.info` | `#2457A7` | Informational state |

> **Accessibility Note:** Status colors are semantic accents, not a replacement for labels or icons. In the monochrome presentation, keep them subtle, localized, and accompanied by iconography.

---

## 3. Typography

Use the platform system sans-serif by default:
- **Android:** Roboto / system sans-serif
- **iOS:** SF Pro / system sans-serif
- **Web / Docs:** Inter / system sans-serif

| Style | Size | Weight | Typical Use |
| :--- | :--- | :--- | :--- |
| **Display** | 32 sp/pt | Bold | Welcome title, key milestones |
| **Screen title** | 22 sp/pt | Semibold/Bold | Page headings |
| **Section title** | 17 sp/pt | Semibold | Group headings |
| **Body** | 16 sp/pt | Regular | Messages and main content |
| **Body emphasized** | 16 sp/pt | Medium | Names and emphasized values |
| **Secondary** | 14 sp/pt | Regular | Supporting information |
| **Caption** | 12 sp/pt | Regular/Medium | Timestamps, compact metadata |
| **Button** | 15–16 sp/pt | Semibold | Button labels |

Use sentence case. Avoid all-caps labels except short technical identifiers. Allow dynamic type and text scaling.

---

## 4. Spacing and Sizing

Use a **4 dp** base grid:

| Token | Value |
| :--- | :--- |
| `space.1` | 4 dp |
| `space.2` | 8 dp |
| `space.3` | 12 dp |
| `space.4` | 16 dp |
| `space.5` | 20 dp |
| `space.6` | 24 dp |
| `space.8` | 32 dp |
| `space.10` | 40 dp |
| `space.12` | 48 dp |

Recommended screen horizontal padding: 20–24 dp. Use 16 dp for compact list rows and 24 dp between major sections.

---

## 5. Shape, Borders, and Elevation

- **Standard card radius:** 16 dp
- **Input and compact button radius:** 12 dp
- **Primary CTA radius:** 12–16 dp
- **Message bubble radius:** 16–20 dp, with a modest sender-side distinction
- **Avatar:** Circular
- **Borders:** 1 dp neutral borders for list separation and outlined controls
- **Elevation:** Prefer subtle elevation or crisp borders over heavy shadows

---

## 6. Component Rules

### Buttons
- **Primary:** Near-black fill, white label, clear action verb.
- **Secondary:** Pale gray fill or neutral outline.
- **Destructive:** Text or outline treatment with error semantic color; require confirmation for irreversible actions.
- **Disabled:** Muted fill and label, while preserving readable contrast.

### Inputs
- White or subtle-gray surface, neutral border, 12 dp radius.
- Show labels persistently; do not rely only on placeholder text.
- Provide clear focus and error states.

### Conversation Rows
- Avatar, name, message preview, timestamp, and unread indicator.
- Keep metadata secondary to the contact name and preview.
- Restrained divider or row spacing without repetitive card elevation.

### Chat Bubbles
- **Incoming:** `#F1F1F1` background with `#111111` text.
- **Outgoing:** `#111111` background with `#FFFFFF` text.
- **Pending/queued state:** Retain bubble styling and show a compact status label/icon underneath.

---

## 7. Motion

- Use brief, purposeful transitions: **150–250 ms**.
- Use motion to indicate connection, progress, or navigation — never for gratuitous decoration.
- Avoid repeated pulsing animations that drain battery life on mobile devices.
- Respect reduced-motion preferences (`prefers-reduced-motion`).
- Radar sweeps and discovery indicators must stop cleanly when discovery is deactivated.

---

## 8. Theme Implementation Verification

- Main screens remain legible in bright daylight and dim environments.
- Text and controls meet WCAG AA contrast targets.
- Selected and unselected navigation states are distinguishable without color alone.
- Pending, delivered, failed, cancelled, and expired messages remain distinguishable via iconography and labels.
- Theme switching does not alter delivery semantics, permissions, or cryptographic verification.

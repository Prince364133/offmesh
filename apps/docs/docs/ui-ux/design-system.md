---
sidebar_position: 1
title: UI/UX & Design System
---

# UI/UX & Design System

OffMesh uses a **Monochrome Minimal** aesthetic tailored for high-contrast visibility in emergency environments, low power consumption on OLED screens, and visual clarity in high-stress transit or village scenarios.

---

## 1. Design Tokens & Color Palette

```css
/* OffMesh Design Tokens */
:root {
  --bg-primary: #0A0E17;       /* Deep Obsidian Space Background */
  --bg-surface: #121824;       /* Card and Container Surface */
  --bg-elevated: #1B2333;      /* Elevated Modal and Dialogue Surface */
  --border-subtle: #242F45;    /* 1px Structural Dividers */

  --accent-cyan: #00F5D4;      /* High-energy Primary Accent (Radar & Send) */
  --accent-blue: #00BBF9;      /* Secondary Network Action Accent */

  --text-primary: #F8F9FA;     /* High-legibility Title Text */
  --text-secondary: #94A3B8;   /* Muted Metadata and Explanatory Labels */

  /* Delivery Status System */
  --status-queued: #FFB703;    /* Amber: Held offline on local phone */
  --status-forwarded: #00F5D4; /* Cyan: Relayed to carrier/gateway */
  --status-delivered: #06D6A0; /* Emerald: Cryptographically verified receipt */
  --status-expired: #EF476F;   /* Ruby: Exceeded max hops or TTL */
}
```

---

## 2. Typography & Hierarchy

The interface utilizes clean, modern typography with clear visual grouping:
* **Display Titles:** Bold sans-serif with tracking for section headers (`Mesh Radar`, `Cloud Gateway & Sync`).
* **Technical Monospace:** Used for cryptographic hashes, node IDs, and safety codes to ensure character distinction (`0` vs `O`, `1` vs `l`).
* **Status Badges:** Small-caps pill containers with integrated icon indicators for fast scanning during movement.

---

## 3. Micro-Interactions & Glassmorphism

* **Subtle Elevation:** Cards and navigation containers use a 1px border (`#242F45`) combined with subtle backdrop blur to create layered depth without heavy shadows.
* **Instant Tactile Feedback:** Every button tap provides immediate micro-transitions (color shifts and scale feedback) to assure users in low-connectivity conditions that their action registered.

# OffMesh --- Theme Specification

**Document type:** Theme and visual language\
**Version:** 1.0\
**Theme name:** Monochrome Minimal\
**Reference:** The supplied OffMesh screen crop featuring a white
background, black logo and primary button, neutral conversation list,
and restrained grayscale chat bubbles.

## 1. Theme intent

The Monochrome Minimal theme is calm, modern, practical, and
content-first. It uses a primarily white canvas, near-black typography
and actions, and carefully tiered neutral grays. It should feel like a
dependable communication utility rather than a flashy social network.

This document defines the default theme. Other themes may be added
later, but they should preserve the same semantic status system, layout
rules, and accessibility behavior.

## 2. Color tokens

Use semantic tokens rather than hard-coded colors throughout components.

  Token                            Hex         Use
  -------------------------------- ----------- --------------------------------------
  `color.background`               `#FFFFFF`   Main app background
  `color.surface`                  `#FFFFFF`   Cards, sheets, message surfaces
  `color.surface.subtle`           `#F7F7F8`   Search fields, quiet panels
  `color.surface.raised`           `#FFFFFF`   Dialogs and elevated surfaces
  `color.text.primary`             `#111111`   Main text and headings
  `color.text.secondary`           `#666666`   Supporting text
  `color.text.tertiary`            `#8A8A8A`   Timestamps and metadata
  `color.border`                   `#E5E5E5`   Dividers, outlines
  `color.border.strong`            `#CFCFCF`   Emphasized boundaries
  `color.action.primary`           `#111111`   Primary buttons and key actions
  `color.action.primary.pressed`   `#333333`   Pressed state
  `color.action.onPrimary`         `#FFFFFF`   Text/icons on primary action
  `color.action.secondary`         `#F2F2F2`   Secondary button surface
  `color.action.secondaryText`     `#111111`   Secondary button label
  `color.focus`                    `#4B6FFF`   Visible keyboard/accessibility focus
  `color.status.pending`           `#8A6500`   Pending state icon/text
  `color.status.success`           `#167A45`   Delivered/success icon/text
  `color.status.warning`           `#A65300`   Warning state
  `color.status.error`             `#B42318`   Failed/cancelled state
  `color.status.info`              `#2457A7`   Informational state

Status colors are semantic accents, not a replacement for labels or
icons. In the monochrome presentation, keep them subtle and localized.

## 3. Typography

Use the platform system sans-serif by default: - Android: Roboto /
system sans-serif. - iOS: SF Pro / system sans-serif.

  Style                   Size Weight           Typical use
  ----------------- ---------- ---------------- ------------------------------
  Display             32 sp/pt Bold             Welcome title, rare
  Screen title              22 Semibold/Bold    Page headings
  Section title             17 Semibold         Group headings
  Body                      16 Regular          Messages and main content
  Body emphasized           16 Medium           Names and emphasized values
  Secondary                 14 Regular          Supporting information
  Caption                   12 Regular/Medium   Timestamps, compact metadata
  Button                15--16 Semibold         Button labels

Use sentence case. Avoid all-caps labels except short technical
identifiers. Allow dynamic type and text scaling.

## 4. Spacing and sizing

Use a 4 dp base grid.

  Token          Value
  ------------ -------
  `space.1`       4 dp
  `space.2`       8 dp
  `space.3`      12 dp
  `space.4`      16 dp
  `space.5`      20 dp
  `space.6`      24 dp
  `space.8`      32 dp
  `space.10`     40 dp
  `space.12`     48 dp

Recommended screen horizontal padding: 20--24 dp. Use 16 dp for compact
list rows and 24 dp between major sections.

## 5. Shape, borders, and elevation

-   Standard card radius: 16 dp.
-   Input and compact button radius: 12 dp.
-   Primary CTA radius: 12--16 dp.
-   Message bubble radius: 16--20 dp, with a modest sender-side
    distinction.
-   Avatar: circular.
-   Use 1 dp neutral borders for list separation and outlined controls.
-   Prefer subtle elevation or borders over heavy shadows.
-   Avoid glassmorphism, excessive gradients, and ornamental backgrounds
    in this theme.

## 6. Iconography

-   Use a consistent 24 dp outline icon family.
-   Prefer simple, familiar symbols for chats, people, nearby, map,
    settings, add, send, QR scan, connection, and status.
-   Use filled variants only for selected navigation or primary states.
-   Every icon-only action must have an accessible label and an adequate
    touch target.

## 7. Component rules

### Buttons

-   Primary: near-black fill, white label, clear action verb.
-   Secondary: pale gray fill or neutral outline.
-   Destructive: text or outline treatment with error semantic color;
    require confirmation for irreversible actions.
-   Disabled: muted fill and label, but preserve readable contrast.

### Inputs

-   White or subtle-gray surface, neutral border, 12 dp radius.
-   Show labels persistently; do not rely only on placeholder text.
-   Provide clear focus and error states.
-   Search fields may use a subtle gray surface.

### Conversation rows

-   Avatar, name, message preview, timestamp, and unread indicator.
-   Keep metadata secondary to the contact name and preview.
-   Use a restrained divider or row spacing; avoid card-heavy
    repetition.

### Chat bubbles

-   Incoming: `#F1F1F1` background with near-black text.
-   Outgoing: `#111111` background with white text.
-   Pending/queued state: retain bubble styling and show a compact
    status label/icon underneath.
-   Do not use color alone to communicate delivery state.

### Navigation

-   Four destinations: Chats, People, Nearby, Settings.
-   Selected item uses a stronger icon/label treatment; unselected items
    use secondary gray.
-   Respect safe areas and platform navigation conventions.

## 8. Motion

-   Use brief, purposeful transitions, typically 150--250 ms.
-   Use motion to indicate connection, progress, or navigation---not as
    decoration.
-   Avoid repeated pulsing or animation that drains battery.
-   Respect reduced-motion preferences.
-   Discovery indicators should remain calm and stop when discovery is
    stopped.

## 9. Responsive behavior

-   Design mobile-first.
-   Support narrow phones, large phones, tablets, and landscape
    orientation.
-   On larger screens, constrain conversation content width and use
    master-detail layouts where appropriate.
-   Ensure bottom navigation and message composer remain clear of system
    insets and keyboard.
-   Support display cutouts and safe areas.

## 10. Theme implementation notes

Create centralized theme tokens and semantic component variants. Do not
scatter hex values across screens. Keep status semantics independent
from theme so a future dark or color theme can be introduced without
changing message-state logic.

Suggested token namespaces: - `color.*` - `type.*` - `space.*` -
`radius.*` - `border.*` - `elevation.*` - `motion.*`

## 11. Theme acceptance criteria

-   Main screens remain legible in bright and dim environments.
-   Text and controls meet contrast requirements.
-   Selected and unselected navigation states are distinguishable
    without color alone.
-   Pending, delivered, failed, cancelled, and expired messages remain
    distinguishable with iconography and labels.
-   Theme changes do not alter delivery semantics, permissions, privacy
    behavior, or message routing.

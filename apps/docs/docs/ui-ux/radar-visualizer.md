---
sidebar_position: 2
title: Airport & Village Mesh Radar
---

# Airport & Village Mesh Radar

The **NearLink Mesh Radar** provides continuous, real-time spatial awareness of nearby radio peers without requiring manual Wi-Fi pairing or Bluetooth PIN pairing.

---

## 1. Visual Architecture

```
                 [ Top Status Bar: Nearby Radios: 3 ]
             
                          . - ~ ~ ~ - .
                      . '       |       ' .
                    /     . - ~ | ~ - .     \
                   /    /       |       \    \
                  |    |    o   |        |    |
                  |----+--------*--------+----|  <- 360-degree rotating sweep
                  |    |        |        |    |
                   \    \       |   o   /    /
                    \     ' - ~ | ~ - '     /
                      . '       |       ' .
                          ' - ~ ~ ~ - '
                          
             [ Peer List: sdk_gphone64 (-52 dBm) - In Sync ]
```

### 1.1 Concentric Range Rings
* **Center Dot:** Represents the user's smartphone (`me`).
* **Ring 1 (Inner):** Ultra-close proximity (up to 2 meters, RSSI greater than -65 dBm). Ideal for high-speed Wi-Fi hotspot bulk transfer.
* **Ring 2 (Mid):** Room/Terminal range (2 - 10 meters, RSSI -65 to -80 dBm). Reliable BLE advertisement and anti-packet exchange.
* **Ring 3 (Outer):** Maximum RF boundary (10 - 30 meters, RSSI below -80 dBm).

### 1.2 The Rotating Radial Sweep
Implemented in Flutter using `CustomPainter` and an infinite rotating `AnimationController`:
* Draws a 90-degree gradient sweep arc that rotates continuously at 2.5 seconds per revolution.
* Discovered devices illuminate as glowing points on the radar grid, with coordinates proportional to their estimated RSSI signal strength.

---

## 2. Radio Discovery Subsystem

1. **Bluetooth Low Energy (BLE):**
   - The device broadcasts a 31-byte advertisement packet containing the 16-byte NearLink Service UUID `00006e4c-0000-1000-8000-00805f9b34fb`.
   - Power consumption in background scanning mode is under **15 mW**, allowing 24-hour operation with negligible battery drain.
2. **Wi-Fi Direct / Local Hotspot Opportunistic Upgrade:**
   - Once devices detect mutual bundle transfer interest via BLE, they can opportunistically establish an ad-hoc Wi-Fi hotspot link to transfer high-volume media or thousands of historical bundles in milliseconds.

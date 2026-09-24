# Feasibility — what ordinary Android phones can actually do offline

Status legend for evidence: **[Doc]** official documentation/spec read this session · **[Paper]** peer-reviewed · **[Src]** source code/project docs · **[Sim]** our simulation · **[Know]** background knowledge not re-verified this session (treat as hypothesis) · **[Untested]** no experiment yet.

## 1. Operating conditions (they are not interchangeable)

| Condition | What is physically available | What can work | Verdict |
|---|---|---|---|
| **A** No internet, radios on | Bluetooth, Wi-Fi hardware | Direct BT/Wi-Fi links between phones within radio range | **Feasible** — this is the prototype's target |
| **B** No internet, no cellular | Same as A (cellular modem irrelevant to BT/Wi-Fi) | Same as A | **Feasible**; cellular coverage is not needed by BT/Wi-Fi [Doc: Wi-Fi Aware "without an access point"] |
| **C** Intermittent neighbours | Occasional contacts | Store-carry-forward (DTN) through participating phones | **Feasible in principle**; latency depends entirely on human movement [Sim, Paper] |
| **D** No nearby compatible device | No shared channel | Nothing. Message stays queued until a contact happens or it expires | **Impossible to deliver**; app must say "queued", not "sent" |
| **E** Long distance, no internet/cellular/extra hardware/infrastructure | Phone radios reach tens of metres | Only via a *chain of people physically carrying phones* (C). No direct long-range path | **Impossible as direct link.** Smallest change: (a) carrier satellite messaging on supported phones+plans, (b) a LoRa radio accessory (e.g. Meshtastic), or (c) any internet path |

Distinctions requested in the brief:
- *No mobile data* ≠ *no internet*: Wi-Fi internet may still exist.
- *No internet* ≠ *no cellular*: SMS/voice may still work.
- *Airplane mode with BT/Wi-Fi re-enabled* = Condition A/B (supported; Android allows re-enabling BT/Wi-Fi in airplane mode [Know]).
- *All radios disabled*: no radio communication at all. Only non-radio channels remain (QR/screen-camera, sound, NFC is a radio) — metres of range, bytes/s.
- *No infrastructure + no extra hardware*: only phone-to-phone radios → Conditions A–D.

## 2. Feasibility matrix

| Approach | Internet? | Cellular? | Extra HW? | Direct? | Multi-hop? | Range | Throughput | Android support | Background | Security | Scalability | Infra | Legal | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Bluetooth Classic RFCOMM** | No | No | No | Yes | Only via app-level store-and-forward | Typ. ~10 m class-2 indoors; unmeasured by us | Plenty for text | AOSP API since API 5; Android 12+ needs BLUETOOTH_SCAN/CONNECT/ADVERTISE [Doc] | Possible in a `connectedDevice` foreground service [Doc]; OEM killers untested | Insecure RFCOMM = no link auth → must do E2E crypto | One link at a time per socket; discovery slow | None | ISM 2.4 GHz, certified radio | [Doc][Untested] |
| **BLE (GATT/advertising)** | No | No | No | Yes | App-level | Similar/longer than Classic, device-dependent | Low–moderate (MTU-limited) | Supported; peripheral mode not on all phones [Know] | Scanning throttled in background [Know] | Same as above | Good for discovery beacons | None | ISM | [Know][Untested] |
| **Wi-Fi Direct (P2P)** | No | No | No | Yes (group owner) | App-level | Tens of metres [Know] | High | API 14+; user-confirm dialogs, NEARBY_WIFI_DEVICES on 13+ [Know] | Poor; connection prompts | Same | Group of few devices | None | ISM | [Know][Untested] |
| **Wi-Fi Aware (NAN)** | No | No | No | Yes | App-level | "longer distances than Bluetooth" (no number given) [Doc] | High | API 26+, **only if `FEATURE_WIFI_AWARE`**; limited data paths [Doc] | Unclear | Same | Limited concurrent data paths [Doc] | None | ISM | [Doc][Untested] |
| **Phone hotspot + TCP (LAN)** | No (hotspot need not have internet) | No | No | Via hotspot phone | App-level | Wi-Fi range | High | Plain sockets; user must join hotspot manually | Works while service alive | Same | ~ up to hotspot client limit | One phone acts as AP | ISM | [Untested]; protocol tested over loopback TCP |
| **Google Nearby Connections** | No ("regardless of network connectivity") [Doc] | No | No | Yes | Cluster strategy; app-level for store-and-forward | BT/BLE/Wi-Fi | High | **Requires Google Play services** [Doc]; from late 2026 apps must ask user to enable radios [Doc: Jul 2026 blog] | Limited | Link encrypted [Doc] | Good | Google Play services on device | ISM | [Doc] |
| **Bluetooth Mesh (SIG)** | No | No | Mesh nodes | — | Yes (managed flooding) | — | Very low | Phones act as provisioner/proxy client via GATT, **not as mesh relay nodes** with standard libs [Src: nRF Mesh lib] | — | Network/app keys | For IoT | Needs mesh devices | ISM | [Src] — **rejected for phone-to-phone** |
| **App-level DTN (store-carry-forward, Spray-and-Wait)** | No | No | No | n/a (runs over any link above) | **Yes** | Unbounded *if people move* | Bounded by contacts | Pure software | Needs background execution | E2E sealing, signed receipts, quotas | Controlled by copy limit L [Paper][Sim] | None | n/a | [Paper][Sim] |
| **Acoustic (data-over-sound, e.g. ggwave)** | No | No | No | Yes | No | Metres | **8–16 bytes/s** [Src] | Mic permission, foreground | Poor | None built-in | Poor (shared air) | None | Fine | [Src] — backup only |
| **Screen→camera QR** | No | No | No | Yes (line of sight) | Carried by hand | < 1 m | ~ kB per code | Camera | Foreground only | Visual eavesdropping | 1:1 | None | Fine | [Know] — good for **key exchange**, not messaging |
| **NFC** | No | No | No | Yes | No | ~ cm | Small | Android Beam removed in Android 10 [Know] | No | — | 1:1 | None | Fine | [Know] — rejected |
| **Carrier satellite messaging (NTN)** | No internet, but **needs carrier satellite service** | Operator/partner service | Supported phone (Android 15+, OEM HAL) [Doc] | Via satellite | n/a | Global where offered | Very low | 3rd-party apps cannot send arbitrary data; only allowlisted/carrier-configured services [Doc] | — | Operator | — | Satellites + operator | Licensed | [Doc] — outside our app's control |
| **LoRa / Meshtastic** | No | No | **Yes (radio)** | Yes | Yes | km-scale (hardware & terrain dependent) [Know] | Very low | via BT to the radio | — | Channel PSK | Moderate | The radios | Region-specific ISM limits (e.g. India 865–867 MHz) [Know] | [Know] — valid "smallest constraint change" for Condition E |
| **GPS/GNSS** | — | — | — | **Receive-only** | — | — | — | — | — | — | — | — | — | [Know] — cannot carry user messages from phones |
| **Transmit on arbitrary frequencies** | — | — | — | — | — | — | — | Phone radios are fixed-function, firmware-locked and type-certified | — | — | — | — | Illegal without licence | [Know] — rejected |

## 3. Conclusions

1. **The feasible system is a local, delay-tolerant network of participating phones.** Direct radio (BT/Wi-Fi) gives single-hop delivery within tens of metres; application-level store-carry-forward extends reach to wherever people carry phones, at human-movement latency.
2. **No software-only path exists for Condition D or for instant long-distance delivery (E)** without internet, cellular, satellite service, or extra radio hardware.
3. **5–10 minute delivery is achievable only when contacts happen that fast.** In our campus simulation, Spray-and-Wait L=8 delivered 45–75% of messages within 60 min and 95–100% within 6 h (3 seeds, synthetic contacts — not a real-world claim).
4. **Transport choice for v0: Bluetooth Classic RFCOMM + LAN TCP (hotspot)** — both pure AOSP, no Google Play dependency, works on de-Googled/Huawei phones. Nearby Connections and Wi-Fi Aware are strong **v1 candidates** behind the same transport-independent core. See DECISIONS.md D-02.
5. **Security must be end-to-end at the bundle level**, because relays are untrusted and Bluetooth "insecure" links are unauthenticated. Bridgefy's history shows adopting a good library is not enough; the protocol around it must be analysed (SECURITY.md).

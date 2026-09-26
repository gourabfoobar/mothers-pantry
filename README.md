# Mother's Pantry

Turn Ma's pasted WhatsApp grocery list into a reviewed, tracked order — matched against a real grocery provider's MCP server, with approvals you can act on from a notification and delivery status that follows on the Lock Screen.

This is a from-scratch rebuild against the [Mother's Pantry design canvas](https://claude.ai/artifact/NNpR3GBPXMVfY2L9WQDzZG) (22 screens, 6 flows). It replaces an earlier Swiggy-staging prototype.

## Layout

```
ios/            SwiftUI app (iOS 17+) + PantryWidgetExtension (ActivityKit Live Activity / Dynamic Island)
backend/        TypeScript/Node — auth, list parsing, matching, cart, orders, APNs push
kirana-now/     Mock MCP grocery server with a seeded catalogue, used for local end-to-end testing
```

## Status

Under active rebuild. See commit history for milestone progress:

0. Repo scaffold (this commit)
1. `kirana-now` mock MCP server
2. Backend skeleton (auth, provider connect, schema)
3. Claude API list parser + matcher + round-down rule
4. Cart/checkout/order placement + APNs payload layer
5. SwiftData models + iOS networking client
6. Onboarding screens (1.1–1.4)
7. Provider connect screens (2.1–2.3)
8. List-building screens (3.1–3.5)
9. Approvals, checkout, placed (4.1–4.5)
10. Live Activity + Dynamic Island + in-app tracking (5.1–5.3)
11. History & account (6.1–6.3)
12. End-to-end pass in Simulator

## Running the iOS app

```
cd ios
xcodegen generate   # regenerates Pantry.xcodeproj from project.yml after any target/source change
open Pantry.xcodeproj
```

Run the `Pantry` scheme on an iOS 17+ simulator.

## Design

Background `#F1F2ED`, cards `#FFFFFF`, ink `#3A3A3A`, secondary text `#6B6D6F`, accent `#EE6F22`, accent text `#B4531A`. Type is JetBrains Mono throughout, with Shippori Mincho for the 母 seal. 16px corner radii, and a hand-drawn ensō motif on welcome/success/loading screens.

# Swiggy Builders Club developer application

Current form: https://forms.gle/4vkeKyqm15Qb6fnJA

The form requires a production HTTPS redirect URI and a publicly viewable demo video link. It says not to enter localhost in the production redirect field. The local development redirect remains http://localhost:8765/oauth/callback.

## Answers ready to paste

**Applicant:** Gourab Baksi (gourabbaksi@gmail.com), Individual Developer

**Team / Project Name:** Mother’s Pantry

**GitHub / Portfolio:** https://github.com/gourabfoobar/mothers-pantry (public repository)

**LinkedIn:** https://www.linkedin.com/in/gourab-baksi

**What are you building?**

Mother’s Pantry is an iPhone grocery assistant for people who receive shopping lists through WhatsApp. A family member can paste a message containing English or romanized Hindi/Bengali grocery names and quantities. Mother’s Pantry searches Swiggy Instamart at the user's chosen saved delivery address, displays the original request next to the proposed product and pack size, flags unavailable items, and requires explicit approval for uncertain names, missing units, substitutions, or materially larger packs. It provides a separate final review before any future order. The current prototype demonstrates matching and review; checkout is disabled while we validate the live provider flow.

**MCP servers:** Swiggy Instamart

**Integration type:** Mobile App

**Tech stack & architecture overview:**

The iOS app is native SwiftUI. A backend bridge connects to Swiggy Instamart MCP over Streamable HTTP using OAuth 2.1 with PKCE and Dynamic Client Registration. The bridge first calls get_addresses and uses an address ID returned by Swiggy for search_products. It shows actual SKU-level variants, pack sizes, availability, and search prices to the user. The local prototype is read-only and stores the OAuth token in memory; it does not log pasted lists or tokens. Before production, we will deploy the backend over HTTPS with secure per-user token storage, add cart/quote validation, and require explicit approval of the current address, items, quantities, fees, total, and payment method before checkout.

**Expected request volume:** < 1K/day

**Public demo video:** https://drive.google.com/file/d/1fyLpDA7YO2cYXIKv0MnsXEq9jJP98vHU/view

**Production redirect URI reserved for the integration:** https://mothers-pantry-bridge.onrender.com/oauth/callback

The Render service is live at https://mothers-pantry-bridge.onrender.com/status and currently runs the demo provider only. Live Swiggy mode requires per-user authentication and token storage before it can safely run on a public server. The GitHub repository is public and available for source review.

The final form page asks for legal name as on government ID, date of birth, PAN, address, business category, agreement email, and confirmation of accuracy. The applicant enters and submits the sensitive legal details directly. Do not claim live production integration, privacy controls, or a security audit that has not been implemented.

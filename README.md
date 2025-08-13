# LLM Coding Challenge – Mobile UI Playground (SwiftUI, iOS 14)

A tiny SwiftUI app that lets users **change the UI with natural‑language prompts**.  
It supports two modes:

1) **LLM-powered** (default when an API key is present) – calls OpenAI and applies returned **structured layout instructions**.  
2) **Mocked** – recognizes a few example prompts and/or pasted JSON; works fully **offline**.

This README reflects the final code that replaces the old `components` array with **top-level `fields` and `button` objects** in both the **instruction model** and the **LLM schema/request**.

---

## Requirements

- **Xcode 12.4** (primary target)
- **iOS 14.0+** deployment target
- Swift 5.3 (no async/await)
- No external packages or CocoaPods

> The project also runs on newer Xcode versions — see **Running on newer Xcode**.

---

## Project structure

```
LLMPlayground/
├── LLMPlaygroundApp.swift        // App entry point (SwiftUI App)
├── ContentView.swift             // UI, state, mocked prompts, JSON decoding
└── OpenAIClient.swift            // Minimal OpenAI client (Chat Completions + JSON schema)
```

---

## Build & run (Xcode **12.4**)

1. Open the project in **Xcode 12.4**.
2. Project settings → confirm:
   - **iOS Deployment Target:** 14.0 (or 14.1+)
   - **Swift Language Version:** 5
3. **(Optional for LLM mode)** Add your OpenAI key:
   - Open `Info.plist` and add a String key `OPENAI_API_KEY` with value `sk-...`
   - Without a key the app still runs using **Mocked** prompts and pasted JSON.
4. Select an iOS 14 simulator (e.g., iPhone 12) and **Run**.

---

## Using the app

- Type free‑form prompts in the bottom input bar and tap **Send**.
- Tap **Reset** to restore defaults.
- You can paste **raw JSON** matching the schema shown below.
- Quick‑action chips expose example prompts.

### Example prompts (mocked & LLM‑friendly)

- `make the background green`
- `make inputs light pink`
- `increase spacing`
- `make the save button outlined and bigger`

---

## Instruction schema

The app expects **this** top‑level JSON shape:

```json
{
  "background": {
    "color": "#10B981"
  },
  "title": {
    "text": "My Profile",
    "color": "#FFFFFF",
    "fontSize": 24
  },
  "fields": {
    "color": "#FFB6C1",
    "textColor": "#000000",
    "cornerRadius": 12
  },
  "button": {
    "color": "#064E3B",
    "outline": true,
    "fontSize": 18,
    "padding": 12,
    "accentColor": "#FFFFFF"
  },
  "layout": {
    "spacing": 32
  }
}
```

- All properties are **optional**; include only what you want to change.
- Colors should be **hex strings** (as the system prompt asks: *“For color references always use hexadecimal.”*).
- The app merges decoded values into the current `LayoutState` and updates the UI in place.

> **Note:** The JSON schema sent to the LLM includes an optional `button.text` field for future use; your `ButtonSpec` ignores it, which is fine.

---

## LLM integration 

`OpenAIClient.layoutInstruction(for:)` calls **Chat Completions** with `response_format: { type: "json_schema" }`.  
The schema mirrors the model above:

```swift
// In OpenAIClient.swift (abbrev.)
let schema: [String: Any] = [
  "name": "layout_instruction",
  "schema": [
    "type": "object",
    "additionalProperties": false,
    "properties": [
      "background": [
        "type": "object",
        "additionalProperties": false,
        "properties": [ "color": ["type": "string"] ]
      ],
      "title": [
        "type": "object",
        "additionalProperties": false,
        "properties": [
          "text": ["type": "string"],
          "color": ["type": "string"],
          "fontSize": ["type": "number"]
        ]
      ],
      "fields": [
        "type": "object",
        "additionalProperties": false,
        "properties": [
          "color": ["type": "string"],
          "textColor": ["type": "string"],
          "cornerRadius": ["type": "number"]
        ]
      ],
      "button": [
        "type": "object",
        "additionalProperties": false,
        "properties": [
          "text": ["type": "string"],       // optional, currently ignored by ButtonSpec
          "color": ["type": "string"],
          "outline": ["type": "boolean"],
          "fontSize": ["type": "number"],
          "padding": ["type": "number"],
          "accentColor": ["type": "string"]
        ]
      ],
      "layout": [
        "type": "object",
        "additionalProperties": false,
        "properties": [ "spacing": ["type": "number"] ]
      ]
    ]
  ]
]
```

Additional request details used by the client:

- `model`: `gpt-4o-mini` (change if desired)
- `temperature`: `0`
- System prompt forces **JSON‑only** output and **hex colors**.

If the API key is missing, the ViewModel falls back to **Mocked** prompts and JSON pastes.

---

## Testing checklist

1. Launch the app: blue background, “My Profile”, two fields, Save button.
2. Enter **“make the background green”** → background turns green.
3. Enter **“make inputs light pink”** → both text fields change color.
4. Enter **“increase spacing”** → vertical spacing increases (e.g., 32).
5. Enter **“make the save button outlined and bigger”** → outlined Save with larger font/padding.
6. Tap **Reset** → initial layout returns.
7. Paste the JSON from **Instruction schema** → all changes apply at once.
8. Remove/invalid API key or disable network → mocked prompts still work.

---

## Running on **newer Xcode** (13–16 / iOS 15–17 SDKs)

This code is backward‑compatible and forward‑friendly.

1. Open in a newer Xcode; accepting **Recommended Settings** is fine.
2. Keep **Deployment Target** at **iOS 14.0** (runs on iOS 15–17 simulators).
3. If preferred, raise the target (e.g., iOS 17) — no code changes are required.
4. Clean build folder (`Shift+Cmd+K`) after migration if you see warnings.
5. Ensure a simulator is installed via **Xcode → Settings → Platforms**.

**Networking tips**
- Default ATS settings allow HTTPS to `api.openai.com`.
- Verify `OPENAI_API_KEY` in `Info.plist`. Network/parse errors are handled as no‑ops in the UI for a smooth demo.

---

## Mocked prompts (for offline demos)

```
make the background green
make inputs light pink
increase spacing
make the save button outlined and bigger
```

> If you hand‑craft JSON, avoid duplicate keys (the last value wins in JSON).

---

## Extending the playground

- Add properties to `FieldSpec` / `ButtonSpec` (e.g., `shadow`, `borderColor`).
- Teach the LLM about new properties by extending the schema in `OpenAIClient.swift`.
- Add more quick‑action chips for reliable demo flows.

---

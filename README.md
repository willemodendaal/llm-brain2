# Brain2

An experiment in modelling a mind with code. Rather than building a chatbot, brain2 models a *person* — with a configurable emotional state, persistent memory, and an observable inner world — then connects that model to an LLM to bring it to life.

<img width="1512" height="741" alt="image" src="https://github.com/user-attachments/assets/67d1f8b6-eebd-41a1-8846-9f74b23d82ef" />

---

## The core idea

The brain isn't an assistant. It's a person sitting at a desk, seeing text appear on their screen, and responding the way a human would — shaped by how they feel right now, what they remember, and who they are.

Each message triggers a pipeline:

1. **Think** — before responding, the brain generates an internal thought: *what am I actually feeling about this?*
2. **React emotionally** — a second focused LLM call assesses the emotional impact of the moment and adjusts the emotion sliders automatically
3. **Respond** — the main reply, during which the brain can also call tools to update emotions further or save memories
4. **Remember** — if something worth keeping comes up, it saves a memory for future conversations

All of this is observable in real-time in the UI's **Inner World** panel.

---

## Interesting bits

### Emotional state as data

Each emotion (fear, confidence, curiosity, etc.) is an Ash resource with a numeric level (0–100) and a `prompt_injection` string. When the level is above zero, that string is injected into the system prompt. When it's zero, it's silently omitted.

This means emotional state has a direct, transparent effect on what the LLM receives — no magic, just string construction you can read in `Brain2.LLM.Chat.build_system_prompt/1`.

The sliders in the UI map directly to database rows. Moving a slider updates the DB, which updates the system prompt shown live in the collapsible panel.

### Emotion adaptation — two paths

Emotions change in two ways, both driven by the LLM itself:

**Post-thought assessment**: immediately after the initial thought is generated, a second LLM call uses `tool_choice: {type: "tool", name: "adjust_emotions"}` to *force* the brain to assess the emotional impact of the moment. This produces a structured list of deltas (`fear +12`, `confidence -8`) which are applied to the DB and shown as chips at the bottom of the thought bubble.

**Mid-response tool calls**: during the main response, the brain has access to `update_emotion` and `adjust_emotions` tools and can call them spontaneously if it feels something shift while composing a reply.

Emotion changes are stored as `EmotionChange` records linked to the `Thought` that triggered them, so there's a full audit trail.

### Thought stream as internal monologue

The brain's internal thoughts are a first-class domain concept — `Brain2.Mind.Thought` — stored in Postgres, not just logged to stdout. This means they're queryable, persistent across restarts, and streamable to the UI.

Each thought entry in the Inner World panel shows the thought text, its timestamp, and the emotion chips from the assessment that followed it.

### Tool use as action vocabulary

The brain doesn't just respond with text. It has a vocabulary of actions it can take via Anthropic tool use:

| Tool | What it does |
|---|---|
| `send_message` | The actual reply (makes "respond or act" explicit) |
| `save_memory` | Persists something for future conversations |
| `search_memory` | Retrieves relevant past memories |
| `update_emotion` | Adjusts a single emotion mid-response |
| `adjust_emotions` | Bulk emotional assessment |
| `imagine_memory` | Generates a plausible memory when asked about something unknown, stores it tagged `#generated` |

The `imagine_memory` tool is particularly interesting: when asked about its past and it has no record, the brain is instructed to fabricate something consistent with its character, store it, and respond as if it were real. Generated memories are displayed in italic violet to make the fabrication visible.

### Memory with provenance

`Brain2.Mind.Memory` is a plain Ash resource. All memories load into the system prompt at the start of each conversation. Generated memories carry a `#generated` tag in the content and are styled differently in the UI — the distinction between remembered and imagined is always visible.

### LLM adapter as a behaviour

`Brain2.LLM.Adapter` is an Elixir behaviour with two callbacks: `complete/3` (the main tool-use loop) and `assess_emotions/3` (the forced single-tool call). The production implementation uses Anthropic directly via `Req`. The test implementation is a simple `Agent` that returns configurable text — no HTTP, no mocking library.

This keeps the full domain and LiveView test suite running without any API calls.

### The tool loop

The Anthropic adapter runs a recursive tool loop: POST → if `stop_reason: "tool_use"` → execute tools via `ToolDispatcher` → append `tool_result` → POST again. It repeats up to 5 rounds. For the emotion assessment call, `tool_choice` forces the model to call a specific tool exactly once, avoiding the loop entirely.

---

## Stack

- **Elixir + Phoenix 1.8 + LiveView** — real-time UI, full-screen three-column layout
- **Ash 3.x + AshPostgres** — domain layer; all state is Ash resources, no raw Ecto
- **PostgreSQL** — persists brain, emotions, thoughts, memories, emotion changes, messages
- **Anthropic API (claude-sonnet-4-6)** — via `Req`, no extra LLM library
- **TailwindCSS v4**

## Running it

```bash
# First time
mix setup                         # deps, create DB, migrate, seed

# Dev
source config/dev.secret.exs     # or set ANTHROPIC_API_KEY in your shell
mix phx.server                    # http://localhost:4000

# Tests (no API key needed — uses FakeAdapter)
mix test

# Before committing
mix precommit
```

`config/dev.secret.exs` is gitignored. Create it with:

```elixir
import Config
config :brain2, :anthropic_api_key, "sk-ant-..."
```

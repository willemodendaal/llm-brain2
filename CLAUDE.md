# Brain2

**App:** brain2 — a mind simulator with configurable emotional state, persistent memory, and an observable inner world, backed by an LLM.

## Stack
- Elixir + Phoenix 1.8 + LiveView
- Ash 3.x + AshPostgres (domain layer — no raw Ecto for domain concepts)
- PostgreSQL
- `Req` for Claude API calls (no extra LLM library)
- TailwindCSS v4

## Domain: `Brain2.Mind`

Single Ash domain. Resources:

| Resource | Purpose |
|---|---|
| `Brain2.Mind.Brain` | The brain entity (name). Singleton — one per app. |
| `Brain2.Mind.EmotionalState` | Named emotion (fear, confidence, etc.), level 0–100, `prompt_injection` text, `default_level` for reset. |
| `Brain2.Mind.Thought` | Internal monologue generated before each response. Has many `EmotionChange`s. |
| `Brain2.Mind.EmotionChange` | Delta applied to an emotion (`from_level`, `to_level`, `reason`). Linked to a `Thought`. |
| `Brain2.Mind.Message` | Chat history. Role `:user` \| `:assistant`. |
| `Brain2.Mind.Memory` | Persistent facts across conversations. Content tagged `#generated` if imagined by the brain. |

Public API is entirely through `Brain2.Mind` functions — no resource modules called directly from outside.

## LLM: `Brain2.LLM`

**Behaviour:** `Brain2.LLM.Adapter` — two callbacks:
- `complete/3` — main tool-use loop; runs recursively until `end_turn` or max rounds
- `assess_emotions/3` — single forced call using `tool_choice` to get `adjust_emotions` output

**Implementations:**
- `Brain2.LLM.Anthropic` — production; calls claude-sonnet-4-6 via `Req`
- `Brain2.LLM.FakeAdapter` — test; returns configurable text from an `Agent`, no HTTP

**Tool vocabulary** (defined in `Brain2.LLM.Chat.tools/0`):
- `send_message` — the reply
- `save_memory` / `search_memory` — long-term memory
- `imagine_memory` — fabricate a plausible memory, store tagged `#generated`
- `update_emotion` — single emotion delta mid-response
- `adjust_emotions` — bulk emotion assessment

**Per-message pipeline in `Brain2.LLM`:**
1. `generate_thought/2` — inner monologue before responding
2. `assess_emotion_impact/3` — forced `adjust_emotions` call; deltas stored as `EmotionChange` records
3. `send_message/2` — main response; brain can call any tool during the loop

**System prompt** (`Brain2.LLM.Chat.build_system_prompt/1`) assembles:
- Persona + starting context + response guidance + memory guidance (module attributes)
- Active emotional state injections (level > 0 only)
- All memories

## UI: `Brain2Web.BrainLive`

Three equal columns, full viewport, no navbar (`full_screen: true` on `Layouts.app`):

| Column | Contents |
|---|---|
| Chat | Message stream + send input |
| Brain Admin | Brain name (rename), emotion sliders (live DB updates), Reset all, Reset to Start |
| Inner World | System Prompt (collapsible), Memories (collapsible, `#generated` shown in italic violet), Thought Stream (with emotion change chips per entry) |

Emotion change chips: amber = increase, cyan = decrease. Hover shows reason.

## Key public functions

```elixir
# Brain
Mind.create_brain(name)
Mind.rename_brain(brain, name)
Mind.first_brain()

# Emotions
Mind.add_emotion(brain, attrs)
Mind.set_emotion_level(state, level)
Mind.reset_emotions(brain)
Mind.build_system_prompt_injection(brain)

# Emotion changes
Mind.apply_emotion_changes(brain, changes, thought_id \\ nil)
Mind.list_emotion_changes_for_thought(thought_id)

# Thoughts
Mind.record_thought(brain, content)     # preloads :emotion_changes
Mind.load_thought_with_changes(thought)
Mind.list_thoughts(brain)               # preloads :emotion_changes

# Messages
Mind.record_message(brain, role, content)
Mind.list_messages(brain)

# Memory
Mind.store_memory(brain, content)
Mind.list_memories(brain)
Mind.search_memories(brain, query)

# Reset
Mind.reset_brain(brain)   # clears messages, thoughts, memories, resets emotions
```

## TDD order
1. Domain tests (`Brain2.Mind.*`) — no LiveView dependency
2. LLM unit tests (`Brain2.LLM.Chat`, `Brain2.LLM.ToolDispatcher`) — pure functions + FakeAdapter
3. LiveView tests last (`Phoenix.LiveViewTest`)

## Run
```
mix setup        # install deps, create DB, migrate, seed
mix phx.server   # start server at localhost:4000
mix test         # run tests (uses FakeAdapter — no API key needed)
mix precommit    # compile + format + test
```

## Secrets
API key lives in `config/dev.secret.exs` (gitignored), imported at the bottom of `config/dev.exs`:
```elixir
import Config
config :brain2, :anthropic_api_key, "sk-ant-..."
```

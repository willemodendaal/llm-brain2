# Brain2

**App:** brain2 — a "thinking brain" simulator with configurable emotional state, backed by an LLM.

## Stack
- Elixir + Phoenix 1.8 + LiveView
- Ash 3.x + AshPostgres (domain layer — no raw Ecto for domain concepts)
- PostgreSQL
- `Req` for Claude API calls (no extra LLM library)
- TailwindCSS v4

## Domain: `Brain2.Mind`
Single Ash domain. Resources:
- `Brain2.Mind.Brain` — the brain entity (name, e.g. "Claude"). One brain per app for now.
- `Brain2.Mind.EmotionalState` — a named emotion with a level (0–100). Belongs to a Brain. Has a `prompt_injection` text that gets injected into the system prompt when level > 0. Has a `default_level` for reset.
- `Brain2.Mind.Message` — chat history. Role `:user` | `:assistant`. Belongs to Brain.

## LLM: `Brain2.LLM`
- Behaviour: `Brain2.LLM` with `chat/2`
- Implementation: `Brain2.LLM.Anthropic` using `Req` directly against Anthropic API
- Brain name configures the assistant persona
- Active emotional states inject their `prompt_injection` text into the system prompt

## UI: `Brain2Web.BrainLive`
50/50 split LiveView:
- **Left (50%):** Chat interface — message list + input
- **Right (50%):** Brain admin — brain name, emotional state attributes with level sliders, Reset button

## Key actions (Ash ubiquitous language)
- `Brain.configure_name(brain, name)` — update brain name
- `EmotionalState.set_level(state, level)` — adjust an emotion
- `EmotionalState.reset_all(brain)` — reset all emotions to default_level
- `Message.send_message(brain, content)` — user sends a message, gets LLM response

## TDD order
1. Domain tests (Ash actions) first — no LiveView dependency
2. LLM module tests (with a mock/stub for API calls)
3. LiveView tests last

## Run
```
mix setup        # install deps, create DB, migrate
mix phx.server   # start server at localhost:4000
mix test         # run tests
mix precommit    # compile + format + test (run before committing)
```

## Env vars
- `ANTHROPIC_API_KEY` — required for LLM calls

# Architectural Decisions

## 2026-05-31 — Ash as domain layer, no raw Ecto

**Decision:** All domain concepts (Brain, EmotionalState, Message) are Ash resources, not raw Ecto schemas.
**Why:** Consistent with the project's stack conventions. Ash provides actions as the public API, keeping LiveViews thin.
**Alternatives considered:** Raw Ecto schemas; simpler initially but creates a path toward god-context bleed.
**Consequences:** All reads/writes go through Ash actions. No `Repo` calls outside of Ash internals.

## 2026-05-31 — Direct Req for LLM, no extra library

**Decision:** Use `Req` (already a dep) to call the Anthropic API directly rather than adding `anthropix` or `langchain`.
**Why:** Project already has `Req`. Adding a dedicated LLM client is an extra dependency for what is ultimately a single HTTP call. A `Brain2.LLM` behaviour keeps it swappable.
**Alternatives considered:** `anthropix`, `elixir_langchain` — both heavier, langchain especially so.
**Consequences:** We own the request shaping code. If Anthropic API changes, we update one module.

## 2026-05-31 — EmotionalState as named domain (not "Attribute")

**Decision:** The personality/state concept is called `EmotionalState`, not generic "Attribute".
**Why:** The domain is explicitly about modelling emotional/psychological states. The ubiquitous language should reflect that. "Attribute" is generic CRUD; "EmotionalState" communicates what it is.
**Alternatives considered:** `Attribute`, `PersonalityTrait` — both vaguer.
**Consequences:** Resource is `Brain2.Mind.EmotionalState`. Reset action resets emotion levels to defaults.

## 2026-05-31 — Perception pipeline (not yet implemented)

**Decision:** Input to the brain will be modeled as a sensory `Perception` (vision: "text on computer screen"), not a raw message. The pipeline is: Perception → Label → EmotionalState update → Thought (internal monologue) → optional Message (what it says).
**Why:** The user framed this explicitly: the brain is a person at a desk seeing text appear. That's a richer model than simple chat. Thoughts are internal and logged separately from what gets said.
**Alternatives considered:** Simple chat model (Perception ≈ Message) — already done as v1. This is the planned v2 of the domain.
**Consequences:** Requires new Ash resources: `Perception`, `Thought`. `EmotionalState` gains an `impact_from_perception` action. `Brain2.LLM` will need a labeling call. This is queued in future.md.

## 2026-05-31 — Single Brain, one-per-app

**Decision:** The app manages one Brain. No multi-brain support.
**Why:** YAGNI. The feature is to model "this brain" — generalization to multiple brains is unneeded now.
**Alternatives considered:** Multi-brain with user association — premature complexity.
**Consequences:** `Brain` is a singleton; seeded on first setup. UI shows one brain.

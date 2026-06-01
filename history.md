# Tech History

Maintained by `/you_worry_about_the_tech`. Newest entries at the top.

---

## 2026-05-31 (session 2)

**What:** Added memory system with Anthropic tool use; added third "Inner World" column with System Prompt, Memories, and Thought Stream panels.
**Why:** Brain needs persistent memory across conversations; LLM should be able to trigger actions (save/search memory, send message) rather than only responding with text.
**Files changed:** lib/brain2/mind/memory.ex, lib/brain2/mind.ex, lib/brain2/llm/tool_dispatcher.ex, lib/brain2/llm/chat.ex, lib/brain2/llm/adapter.ex, lib/brain2/llm/anthropic.ex, lib/brain2/llm/fake_adapter.ex, lib/brain2/llm.ex, lib/brain2_web/live/brain_live.ex, lib/brain2_web/components/layouts.ex, assets/js/app.js. 41 tests, 0 failures.

---

## 2026-05-31

**What:** Initial project setup — Ash domain, LLM integration, Phoenix LiveView 50/50 UI.
**Why:** Green-field project. Established domain layer (Brain, EmotionalState, Message), LLM adapter behaviour with Anthropic implementation + FakeAdapter for tests, and a LiveView with chat + brain admin panels.
**Files changed:** mix.exs, lib/brain2/mind.ex, lib/brain2/mind/brain.ex, lib/brain2/mind/emotional_state.ex, lib/brain2/mind/message.ex, lib/brain2/llm.ex, lib/brain2/llm/chat.ex, lib/brain2/llm/adapter.ex, lib/brain2/llm/anthropic.ex, lib/brain2/llm/fake_adapter.ex, lib/brain2_web/live/brain_live.ex, lib/brain2_web/router.ex, priv/repo/seeds.exs, test/ (24 tests, 0 failures).

---

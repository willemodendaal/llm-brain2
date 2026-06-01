# Tech Future

Things flagged for improvement. Pull from here when invoking `/you_worry_about_the_tech`.

---

- [ ] **Memory deletion** — let the brain forget things. `forget_memory` tool + delete button in the Memories panel. — *domain action* `#claude`

- [ ] **Perception pipeline** — model sensory input as a first-class domain concept: `Brain2.Mind.Perception`. A `Perception` represents "text appearing on the screen" (vision channel). It is labeled/categorized first, then influences `EmotionalState`, then triggers `Thought` (internal monologue), then optionally produces a `Message`. All logged to DB, internal thoughts streamed to the right panel of the UI. — *DDD: missing domain concept, currently implicit in LiveView* `#claude`

- [ ] **Thought/internal monologue resource** — `Brain2.Mind.Thought` resource. The brain's internal processing step: what does it think before responding? Logged to DB, streamed to brain admin panel (right side). Separate from `Message` (which is what it *says*). — *missing domain concept* `#claude`

- [ ] **Emotional impact from perception** — when a perception arrives, analyze its emotional content and auto-adjust emotional state levels. Could use a secondary LLM call or simple rules. — *domain behaviour not yet modeled* `#claude`

- [ ] **Labeling step** — first stage of perception pipeline: categorize the input (e.g. "question", "command", "emotional appeal", "threat"). Separate Ash action on `Perception`. — *domain behaviour* `#claude`

- [ ] **Thought streaming to UI** — stream internal `Thought` records to the brain admin panel in real-time using Phoenix PubSub + LiveView. Separate from the chat messages. — *UI feature* `#claude`

- [ ] **Processing layer** — after the thought is generated, run a configurable "reflection" step. This step: (a) adjusts emotional state sliders based on what was just said/thought, and (b) can modify any brain parameters. The reflection is itself an LLM call with a structured output (e.g. JSON: `{fear: +10, confidence: -5, note: "that question felt probing"}`). Log the reflection as a collapsible panel in the Inner World column, above or below the thought stream. The emotion slider changes should be visible in real-time in the Brain Admin panel. — *new domain concept: `Reflection`, structured LLM output, real-time slider updates* `#claude`

- [ ] **ANTHROPIC_API_KEY in runtime.exs** — move key config to `config/runtime.exs` so it reads from env at startup, not compile time. — *infrastructure hygiene* `#claude`

- [ ] **Fly.io deployment** — deploy to Fly with `ANTHROPIC_API_KEY` as a secret. — `#will`

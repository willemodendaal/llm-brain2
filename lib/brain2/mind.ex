defmodule Brain2.Mind do
  use Ash.Domain

  require Ash.Query

  resources do
    resource(Brain2.Mind.Brain)
    resource(Brain2.Mind.EmotionalState)
    resource(Brain2.Mind.Message)
    resource(Brain2.Mind.Thought)
    resource(Brain2.Mind.Memory)
    resource(Brain2.Mind.EmotionChange)
  end

  # Brain actions

  def create_brain(name) do
    Brain2.Mind.Brain
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create()
  end

  def rename_brain(brain, name) do
    brain
    |> Ash.Changeset.for_update(:rename, %{name: name})
    |> Ash.update()
  end

  def get_brain!(id) do
    Ash.get!(Brain2.Mind.Brain, id)
  end

  def first_brain do
    Brain2.Mind.Brain
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  # EmotionalState actions

  def add_emotion(brain, attrs) do
    Brain2.Mind.EmotionalState
    |> Ash.Changeset.for_create(:add, Map.put(attrs, :brain_id, brain.id))
    |> Ash.create()
  end

  def set_emotion_level(state, level) do
    state
    |> Ash.Changeset.for_update(:set_level, %{level: level})
    |> Ash.update()
  end

  def list_emotions(brain) do
    Brain2.Mind.EmotionalState
    |> Ash.Query.filter(brain_id: brain.id)
    |> Ash.Query.sort(:name)
    |> Ash.read!()
  end

  def reset_emotions(brain) do
    brain
    |> list_emotions()
    |> Enum.each(fn state ->
      state
      |> Ash.Changeset.for_update(:reset_to_default, %{})
      |> Ash.update!()
    end)

    :ok
  end

  def build_system_prompt_injection(brain) do
    brain
    |> list_emotions()
    |> Enum.filter(fn e -> e.level > 0 end)
    |> Enum.map_join("\n", fn e -> e.prompt_injection end)
  end

  # Message actions

  def record_message(brain, role, content) do
    Brain2.Mind.Message
    |> Ash.Changeset.for_create(:record, %{role: role, content: content, brain_id: brain.id})
    |> Ash.create()
  end

  def list_messages(brain) do
    Brain2.Mind.Message
    |> Ash.Query.filter(brain_id: brain.id)
    |> Ash.Query.sort(:inserted_at)
    |> Ash.read!()
  end

  # Thought actions

  def record_thought(brain, content) do
    with {:ok, thought} <-
           Brain2.Mind.Thought
           |> Ash.Changeset.for_create(:record, %{content: content, brain_id: brain.id})
           |> Ash.create() do
      {:ok, Ash.load!(thought, :emotion_changes)}
    end
  end

  def list_thoughts(brain) do
    Brain2.Mind.Thought
    |> Ash.Query.filter(brain_id: brain.id)
    |> Ash.Query.sort(:inserted_at)
    |> Ash.Query.load(:emotion_changes)
    |> Ash.read!()
  end

  def load_thought_with_changes(thought) do
    Ash.load!(thought, :emotion_changes)
  end

  def apply_emotion_changes(brain, changes, thought_id \\ nil) do
    emotions = list_emotions(brain)
    emotion_map = Map.new(emotions, &{&1.name, &1})

    results =
      Enum.flat_map(changes, fn change ->
        name = to_string(change[:emotion] || change["emotion"])
        raw_delta = change[:delta] || change["delta"]
        delta = if is_binary(raw_delta), do: String.to_integer(raw_delta), else: raw_delta
        reason = change[:reason] || change["reason"]

        case Map.get(emotion_map, name) do
          nil ->
            []

          emotion ->
            new_level = emotion.level + delta |> then(&Kernel.max(0, &1)) |> then(&Kernel.min(100, &1))
            set_emotion_level(emotion, new_level)

            {:ok, record} =
              Brain2.Mind.EmotionChange
              |> Ash.Changeset.for_create(:record, %{
                emotion_name: name,
                delta: delta,
                from_level: emotion.level,
                to_level: new_level,
                reason: reason,
                thought_id: thought_id,
                brain_id: brain.id
              })
              |> Ash.create()

            [record]
        end
      end)

    {:ok, results}
  end

  def list_emotion_changes_for_thought(thought_id) do
    Brain2.Mind.EmotionChange
    |> Ash.Query.filter(thought_id: thought_id)
    |> Ash.Query.sort(:inserted_at)
    |> Ash.read!()
  end

  def reset_brain(brain) do
    for resource <- [Brain2.Mind.Message, Brain2.Mind.Thought, Brain2.Mind.Memory] do
      resource
      |> Ash.Query.filter(brain_id: brain.id)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!/1)
    end

    reset_emotions(brain)
  end

  # Memory actions

  def store_memory(brain, content) do
    Brain2.Mind.Memory
    |> Ash.Changeset.for_create(:store, %{content: content, brain_id: brain.id})
    |> Ash.create()
  end

  def list_memories(brain) do
    Brain2.Mind.Memory
    |> Ash.Query.filter(brain_id: brain.id)
    |> Ash.Query.sort(:inserted_at)
    |> Ash.read!()
  end

  def search_memories(brain, query) do
    lowered = String.downcase(query)

    brain
    |> list_memories()
    |> Enum.filter(fn m -> String.contains?(String.downcase(m.content), lowered) end)
  end
end

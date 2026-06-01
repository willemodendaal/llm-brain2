defmodule Brain2.Mind.EmotionChangeTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")

    {:ok, fear} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 20,
        default_level: 0,
        prompt_injection: "You are afraid."
      })

    {:ok, confidence} =
      Mind.add_emotion(brain, %{
        name: "confidence",
        level: 60,
        default_level: 60,
        prompt_injection: "You are confident."
      })

    %{brain: brain, fear: fear, confidence: confidence}
  end

  test "apply_emotion_changes updates levels and records changes", %{brain: brain} do
    changes = [
      %{emotion: "fear", delta: 30, reason: "That felt threatening"},
      %{emotion: "confidence", delta: -10, reason: "I'm not sure"}
    ]

    assert {:ok, applied} = Mind.apply_emotion_changes(brain, changes)
    assert length(applied) == 2

    fear = Mind.list_emotions(brain) |> Enum.find(&(&1.name == "fear"))
    confidence = Mind.list_emotions(brain) |> Enum.find(&(&1.name == "confidence"))

    assert fear.level == 50
    assert confidence.level == 50
  end

  test "records from/to levels on each change", %{brain: brain} do
    changes = [%{emotion: "fear", delta: 15, reason: "Unsettling"}]

    {:ok, [change]} = Mind.apply_emotion_changes(brain, changes)
    assert change.from_level == 20
    assert change.to_level == 35
    assert change.delta == 15
    assert change.reason == "Unsettling"
  end

  test "clamps level to 0–100", %{brain: brain} do
    changes = [%{emotion: "fear", delta: 200, reason: "Overwhelmed"}]
    {:ok, _} = Mind.apply_emotion_changes(brain, changes)
    fear = Mind.list_emotions(brain) |> Enum.find(&(&1.name == "fear"))
    assert fear.level == 100
  end

  test "ignores unknown emotion names gracefully", %{brain: brain} do
    changes = [%{emotion: "nonexistent", delta: 10, reason: "???"}]
    assert {:ok, []} = Mind.apply_emotion_changes(brain, changes)
  end

  test "links changes to a thought when thought_id provided", %{brain: brain} do
    {:ok, thought} = Mind.record_thought(brain, "Something happened.")
    changes = [%{emotion: "fear", delta: 5, reason: "Mild concern"}]

    {:ok, [change]} = Mind.apply_emotion_changes(brain, changes, thought.id)
    assert change.thought_id == thought.id
  end

  test "lists emotion changes for a thought", %{brain: brain} do
    {:ok, thought} = Mind.record_thought(brain, "Processing...")
    changes = [
      %{emotion: "fear", delta: 10, reason: "A"},
      %{emotion: "confidence", delta: -5, reason: "B"}
    ]

    Mind.apply_emotion_changes(brain, changes, thought.id)
    loaded = Mind.list_emotion_changes_for_thought(thought.id)
    assert length(loaded) == 2
  end
end

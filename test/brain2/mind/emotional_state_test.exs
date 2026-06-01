defmodule Brain2.Mind.EmotionalStateTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")
    %{brain: brain}
  end

  test "adds an emotional state to a brain", %{brain: brain} do
    assert {:ok, state} =
             Mind.add_emotion(brain, %{
               name: "fear",
               level: 70,
               default_level: 0,
               prompt_injection: "You answer as if you are quite afraid and possibly defensive."
             })

    assert state.name == "fear"
    assert state.level == 70
    assert state.brain_id == brain.id
  end

  test "level must be 0–100", %{brain: brain} do
    assert {:error, _} =
             Mind.add_emotion(brain, %{
               name: "fear",
               level: 150,
               default_level: 0,
               prompt_injection: "..."
             })
  end

  test "sets level on an existing emotion", %{brain: brain} do
    {:ok, state} =
      Mind.add_emotion(brain, %{
        name: "confidence",
        level: 20,
        default_level: 50,
        prompt_injection: "You answer with great confidence."
      })

    assert {:ok, updated} = Mind.set_emotion_level(state, 90)
    assert updated.level == 90
  end

  test "resets all emotions to default_level", %{brain: brain} do
    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 80,
        default_level: 10,
        prompt_injection: "Afraid."
      })

    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "joy",
        level: 90,
        default_level: 50,
        prompt_injection: "Joyful."
      })

    assert :ok = Mind.reset_emotions(brain)

    emotions = Mind.list_emotions(brain)
    assert Enum.all?(emotions, fn e -> e.level == e.default_level end)
  end

  test "builds system prompt injection from active emotions", %{brain: brain} do
    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 70,
        default_level: 0,
        prompt_injection: "You are quite afraid."
      })

    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "joy",
        level: 0,
        default_level: 0,
        prompt_injection: "You are joyful."
      })

    injection = Mind.build_system_prompt_injection(brain)
    assert injection =~ "You are quite afraid."
    refute injection =~ "You are joyful."
  end
end

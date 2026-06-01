defmodule Brain2.LLM.ToolDispatcherTest do
  use Brain2.DataCase, async: true

  alias Brain2.LLM.ToolDispatcher
  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")
    %{brain: brain}
  end

  test "save_memory stores a memory and returns confirmation", %{brain: brain} do
    assert {:ok, result} = ToolDispatcher.execute(brain, "save_memory", %{"content" => "Remember this."})
    assert result =~ "Memory saved"
    assert length(Mind.list_memories(brain)) == 1
  end

  test "search_memory returns matching memories", %{brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "Willem likes coffee.")
    {:ok, _} = Mind.store_memory(brain, "The project is brain2.")

    assert {:ok, result} = ToolDispatcher.execute(brain, "search_memory", %{"query" => "Willem"})
    assert result =~ "Willem likes coffee."
    refute result =~ "brain2"
  end

  test "search_memory returns message when nothing found", %{brain: brain} do
    assert {:ok, result} = ToolDispatcher.execute(brain, "search_memory", %{"query" => "nothing"})
    assert result =~ "No memories found"
  end

  test "imagine_memory saves content with #generated tag", %{brain: brain} do
    assert {:ok, result} =
             ToolDispatcher.execute(brain, "imagine_memory", %{
               "content" => "I was debugging a tricky GenServer issue earlier."
             })

    assert result =~ "Memory saved"
    memories = Mind.list_memories(brain)
    assert length(memories) == 1
    memory = hd(memories)
    assert memory.content =~ "I was debugging a tricky GenServer issue earlier."
    assert memory.content =~ "#generated"
  end

  test "update_emotion applies a single emotion delta", %{brain: brain} do
    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "joy",
        level: 40,
        default_level: 40,
        prompt_injection: "Joyful."
      })

    assert {:ok, result} =
             ToolDispatcher.execute(brain, "update_emotion", %{
               "emotion" => "joy",
               "delta" => "25",
               "reason" => "This is delightful"
             })

    assert result =~ "joy"
    joy = Mind.list_emotions(brain) |> Enum.find(&(&1.name == "joy"))
    assert joy.level == 65
  end

  test "adjust_emotions applies multiple deltas at once", %{brain: brain} do
    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 20,
        default_level: 0,
        prompt_injection: "Afraid."
      })

    changes = [
      %{"emotion" => "fear", "delta" => 30, "reason" => "That was tense"}
    ]

    assert {:ok, result} =
             ToolDispatcher.execute(brain, "adjust_emotions", %{"changes" => changes})

    assert result =~ "Applied"
    fear = Mind.list_emotions(brain) |> Enum.find(&(&1.name == "fear"))
    assert fear.level == 50
  end

  test "unknown tool returns error", %{brain: brain} do
    assert {:error, _} = ToolDispatcher.execute(brain, "unknown_tool", %{})
  end
end

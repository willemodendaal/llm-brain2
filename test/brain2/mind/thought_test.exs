defmodule Brain2.Mind.ThoughtTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")
    %{brain: brain}
  end

  test "records a thought for a brain", %{brain: brain} do
    assert {:ok, thought} = Mind.record_thought(brain, "I wonder what they mean by that.")
    assert thought.content == "I wonder what they mean by that."
    assert thought.brain_id == brain.id
  end

  test "lists thoughts in insertion order", %{brain: brain} do
    {:ok, _} = Mind.record_thought(brain, "First thought")
    {:ok, _} = Mind.record_thought(brain, "Second thought")

    thoughts = Mind.list_thoughts(brain)
    assert length(thoughts) == 2
    assert hd(thoughts).content == "First thought"
  end
end

defmodule Brain2.Mind.MemoryTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")
    %{brain: brain}
  end

  test "stores a memory", %{brain: brain} do
    assert {:ok, mem} = Mind.store_memory(brain, "Willem likes dark roast coffee.")
    assert mem.content == "Willem likes dark roast coffee."
    assert mem.brain_id == brain.id
  end

  test "lists all memories in order", %{brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "First memory")
    {:ok, _} = Mind.store_memory(brain, "Second memory")

    memories = Mind.list_memories(brain)
    assert length(memories) == 2
    assert hd(memories).content == "First memory"
  end

  test "searches memories by substring", %{brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "Willem likes dark roast coffee.")
    {:ok, _} = Mind.store_memory(brain, "The project is called brain2.")
    {:ok, _} = Mind.store_memory(brain, "Willem lives in Cape Town.")

    results = Mind.search_memories(brain, "Willem")
    assert length(results) == 2
    assert Enum.all?(results, &String.contains?(&1.content, "Willem"))
  end

  test "search is case-insensitive", %{brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "Willem likes coffee.")
    results = Mind.search_memories(brain, "willem")
    assert length(results) == 1
  end
end

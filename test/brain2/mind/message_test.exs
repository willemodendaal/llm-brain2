defmodule Brain2.Mind.MessageTest do
  use Brain2.DataCase, async: true

  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("Claude")
    %{brain: brain}
  end

  test "stores a user message", %{brain: brain} do
    assert {:ok, msg} = Mind.record_message(brain, :user, "Hello!")
    assert msg.role == :user
    assert msg.content == "Hello!"
    assert msg.brain_id == brain.id
  end

  test "stores an assistant message", %{brain: brain} do
    assert {:ok, msg} = Mind.record_message(brain, :assistant, "Hi there!")
    assert msg.role == :assistant
  end

  test "lists messages in order", %{brain: brain} do
    {:ok, _} = Mind.record_message(brain, :user, "First")
    {:ok, _} = Mind.record_message(brain, :assistant, "Second")

    messages = Mind.list_messages(brain)
    assert length(messages) == 2
    assert hd(messages).content == "First"
  end
end

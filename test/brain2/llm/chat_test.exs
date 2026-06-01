defmodule Brain2.LLM.ChatTest do
  use Brain2.DataCase, async: true

  alias Brain2.LLM.Chat
  alias Brain2.Mind

  setup do
    {:ok, brain} = Mind.create_brain("TestBrain")

    {:ok, _} =
      Mind.add_emotion(brain, %{
        name: "fear",
        level: 80,
        default_level: 0,
        prompt_injection: "You are quite afraid."
      })

    %{brain: brain}
  end

  test "builds system prompt with brain name and active emotions", %{brain: brain} do
    prompt = Chat.build_system_prompt(brain)
    assert prompt =~ "TestBrain"
    assert prompt =~ "You are quite afraid."
  end

  test "includes memories in system prompt when present", %{brain: brain} do
    {:ok, _} = Mind.store_memory(brain, "Willem lives in Cape Town.")
    prompt = Chat.build_system_prompt(brain)
    assert prompt =~ "Willem lives in Cape Town."
  end

  test "builds messages list for LLM from history + new user message", %{brain: brain} do
    {:ok, _} = Mind.record_message(brain, :user, "Hello")
    {:ok, _} = Mind.record_message(brain, :assistant, "Hi there")

    messages = Chat.build_messages(brain, "New question")

    assert [
             %{role: "user", content: "Hello"},
             %{role: "assistant", content: "Hi there"},
             %{role: "user", content: content}
           ] = messages

    assert content =~ "New question"
  end

  test "system prompt includes persona and starting context", %{brain: brain} do
    prompt = Chat.build_system_prompt(brain)
    assert prompt =~ "colleague"
    assert prompt =~ "desk"
  end

  test "system prompt instructs short chat responses", %{brain: brain} do
    prompt = Chat.build_system_prompt(brain)
    assert prompt =~ "paragraph"
  end

  test "system prompt instructs brain to imagine and store when uncertain", %{brain: brain} do
    prompt = Chat.build_system_prompt(brain)
    assert prompt =~ "imagine_memory"
    assert prompt =~ "#generated"
  end

  test "imagine_memory tool is in tool definitions" do
    names = Chat.tools() |> Enum.map(& &1.name)
    assert "imagine_memory" in names
  end

  test "returns tool definitions", %{brain: _brain} do
    tools = Chat.tools()
    names = Enum.map(tools, & &1.name)
    assert "save_memory" in names
    assert "search_memory" in names
    assert "send_message" in names
  end
end

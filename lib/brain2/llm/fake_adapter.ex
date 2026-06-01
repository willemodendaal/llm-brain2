defmodule Brain2.LLM.FakeAdapter do
  @behaviour Brain2.LLM.Adapter

  @agent __MODULE__

  def start_link(_), do: Agent.start_link(fn -> "I am a test response." end, name: @agent)
  def child_spec(opts), do: %{id: @agent, start: {__MODULE__, :start_link, [opts]}}

  def set_response(text), do: Agent.update(@agent, fn _ -> text end)

  @impl true
  def complete(_system_prompt, _messages, _brain) do
    {:ok, Agent.get(@agent, & &1)}
  end

  @impl true
  def assess_emotions(_system_prompt, _messages, _brain) do
    {:ok, []}
  end
end

defmodule Brain2.LLM.Anthropic do
  @behaviour Brain2.LLM.Adapter

  alias Brain2.LLM.{Chat, ToolDispatcher}

  @api_url "https://api.anthropic.com/v1/messages"
  @model "claude-sonnet-4-6"
  @max_tokens 1024
  @max_tool_rounds 5

  @impl true
  def complete(system_prompt, messages, brain) do
    api_key = Application.fetch_env!(:brain2, :anthropic_api_key)
    run_tool_loop(api_key, system_prompt, messages, brain, @max_tool_rounds)
  end

  @impl true
  def assess_emotions(system_prompt, messages, brain) do
    api_key = Application.fetch_env!(:brain2, :anthropic_api_key)
    adjust_tool = Enum.find(Chat.tools(), &(&1.name == "adjust_emotions"))

    case Req.post(@api_url,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ],
           json: %{
             model: @model,
             max_tokens: 512,
             system: system_prompt,
             tools: [adjust_tool],
             tool_choice: %{type: "tool", name: "adjust_emotions"},
             messages: messages
           }
         ) do
      {:ok, %{status: 200, body: %{"content" => blocks}}} ->
        tool_uses = Enum.filter(blocks, &(&1["type"] == "tool_use"))

        changes =
          Enum.flat_map(tool_uses, fn %{"name" => "adjust_emotions", "input" => %{"changes" => ch}} ->
            Enum.map(ch, fn c ->
              %{emotion: c["emotion"], delta: c["delta"], reason: c["reason"]}
            end)
          end)

        {:ok, changes}

      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_tool_loop(_api_key, _system, _messages, _brain, 0) do
    {:error, "Tool loop exceeded maximum rounds"}
  end

  defp run_tool_loop(api_key, system_prompt, messages, brain, rounds_left) do
    case post(api_key, system_prompt, messages) do
      {:ok, %{"stop_reason" => "tool_use", "content" => content_blocks}} ->
        {tool_uses, _text} = split_content(content_blocks)

        tool_results =
          Enum.map(tool_uses, fn %{"id" => id, "name" => name, "input" => input} ->
            result_text =
              case ToolDispatcher.execute(brain, name, input) do
                {:ok, text} -> text
                {:error, msg} -> "Error: #{msg}"
              end

            %{type: "tool_result", tool_use_id: id, content: result_text}
          end)

        assistant_turn = %{
          role: "assistant",
          content: content_blocks
        }

        user_results_turn = %{
          role: "user",
          content: tool_results
        }

        updated_messages = messages ++ [assistant_turn, user_results_turn]
        run_tool_loop(api_key, system_prompt, updated_messages, brain, rounds_left - 1)

      {:ok, %{"stop_reason" => "end_turn", "content" => content_blocks}} ->
        extract_reply(content_blocks)

      {:ok, %{"stop_reason" => other}} ->
        {:error, "Unexpected stop_reason: #{other}"}

      {:error, _} = err ->
        err
    end
  end

  defp post(api_key, system_prompt, messages) do
    case Req.post(@api_url,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ],
           json: %{
             model: @model,
             max_tokens: @max_tokens,
             system: system_prompt,
             tools: Chat.tools(),
             messages: messages
           }
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp split_content(blocks) do
    tool_uses = Enum.filter(blocks, &(&1["type"] == "tool_use"))

    text =
      blocks
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map_join(" ", & &1["text"])

    {tool_uses, text}
  end

  defp extract_reply(blocks) do
    # Prefer send_message tool call if present, otherwise fall back to text
    tool_uses = Enum.filter(blocks, &(&1["type"] == "tool_use"))

    send_msg =
      Enum.find(tool_uses, fn b -> b["name"] == "send_message" end)

    cond do
      send_msg ->
        {:ok, send_msg["input"]["content"]}

      true ->
        text =
          blocks
          |> Enum.filter(&(&1["type"] == "text"))
          |> Enum.map_join(" ", & &1["text"])

        if text != "", do: {:ok, text}, else: {:error, "Empty response"}
    end
  end
end

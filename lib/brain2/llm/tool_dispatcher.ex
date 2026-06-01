defmodule Brain2.LLM.ToolDispatcher do
  alias Brain2.Mind

  @spec execute(Mind.Brain.t(), String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}

  def execute(brain, "save_memory", %{"content" => content}) do
    case Mind.store_memory(brain, content) do
      {:ok, _} -> {:ok, "Memory saved: \"#{content}\""}
      {:error, _} -> {:error, "Failed to save memory."}
    end
  end

  def execute(brain, "search_memory", %{"query" => query}) do
    case Mind.search_memories(brain, query) do
      [] ->
        {:ok, "No memories found for: \"#{query}\""}

      memories ->
        result =
          memories
          |> Enum.map_join("\n", fn m -> "- #{m.content}" end)

        {:ok, "Found #{length(memories)} memories:\n#{result}"}
    end
  end

  def execute(brain, "update_emotion", %{"emotion" => emotion} = params) do
    delta = params["delta"] || 0
    reason = params["reason"]

    case Mind.apply_emotion_changes(brain, [%{emotion: emotion, delta: delta, reason: reason}]) do
      {:ok, [change]} ->
        {:ok, "Updated #{emotion}: #{format_delta(change.delta)} (#{change.from_level}→#{change.to_level})"}

      {:ok, []} ->
        {:ok, "No emotion named '#{emotion}' found."}

      {:error, _} ->
        {:error, "Failed to update emotion."}
    end
  end

  def execute(brain, "adjust_emotions", %{"changes" => changes}) do
    parsed =
      Enum.map(changes, fn c ->
        %{emotion: c["emotion"], delta: c["delta"], reason: c["reason"]}
      end)

    case Mind.apply_emotion_changes(brain, parsed) do
      {:ok, applied} when applied != [] ->
        summary =
          Enum.map_join(applied, ", ", fn c ->
            "#{c.emotion_name} #{format_delta(c.delta)}"
          end)

        {:ok, "Applied emotion changes: #{summary}"}

      {:ok, []} ->
        {:ok, "No matching emotions found."}

      {:error, _} ->
        {:error, "Failed to adjust emotions."}
    end
  end

  def execute(brain, "imagine_memory", %{"content" => content}) do
    full_content = "#{content} #generated"

    case Mind.store_memory(brain, full_content) do
      {:ok, _} -> {:ok, "Memory saved (generated): \"#{full_content}\""}
      {:error, _} -> {:error, "Failed to save generated memory."}
    end
  end

  def execute(_brain, name, _input) do
    {:error, "Unknown tool: #{name}"}
  end

  defp format_delta(d) when d >= 0, do: "+#{d}"
  defp format_delta(d), do: "#{d}"
end

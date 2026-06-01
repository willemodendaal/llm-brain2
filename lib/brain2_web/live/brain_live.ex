defmodule Brain2Web.BrainLive do
  use Brain2Web, :live_view

  alias Brain2.{Mind, LLM}
  alias Brain2.LLM.Chat

  @impl true
  def mount(_params, _session, socket) do
    brain = get_or_create_brain()
    emotions = Mind.list_emotions(brain)
    messages = Mind.list_messages(brain)
    thoughts = Mind.list_thoughts(brain)
    memories = Mind.list_memories(brain)

    socket =
      socket
      |> assign(:brain, brain)
      |> assign(:emotions, emotions)
      |> assign(:sending, false)
      |> assign(:system_prompt, Chat.build_system_prompt(brain))
      |> stream(:messages, messages)
      |> stream(:thoughts, thoughts)
      |> stream(:memories, memories)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) when content != "" do
    brain = socket.assigns.brain
    {:ok, user_msg} = Mind.record_message(brain, :user, content)

    socket =
      socket
      |> stream_insert(:messages, user_msg)
      |> assign(:sending, true)
      |> push_event("clear-input", %{})

    send(self(), {:call_llm, content})

    {:noreply, socket}
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  def handle_event("rename_brain", %{"name" => name}, socket) do
    case Mind.rename_brain(socket.assigns.brain, name) do
      {:ok, brain} ->
        {:noreply, socket |> assign(:brain, brain) |> assign(:system_prompt, Chat.build_system_prompt(brain))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("set_emotion_level", %{"emotion_id" => id, "level" => level}, socket) do
    {level_int, _} = Integer.parse(level)
    emotion = Enum.find(socket.assigns.emotions, &(&1.id == id))

    case Mind.set_emotion_level(emotion, level_int) do
      {:ok, updated} ->
        emotions = Enum.map(socket.assigns.emotions, fn e -> if e.id == id, do: updated, else: e end)
        brain = socket.assigns.brain
        {:noreply, socket |> assign(:emotions, emotions) |> assign(:system_prompt, Chat.build_system_prompt(brain))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_emotions", _params, socket) do
    brain = socket.assigns.brain
    :ok = Mind.reset_emotions(brain)
    emotions = Mind.list_emotions(brain)
    {:noreply, socket |> assign(:emotions, emotions) |> assign(:system_prompt, Chat.build_system_prompt(brain))}
  end

  def handle_event("reset_to_start", _params, socket) do
    brain = socket.assigns.brain
    :ok = Mind.reset_brain(brain)
    emotions = Mind.list_emotions(brain)

    socket =
      socket
      |> assign(:emotions, emotions)
      |> assign(:system_prompt, Chat.build_system_prompt(brain))
      |> stream(:messages, [], reset: true)
      |> stream(:thoughts, [], reset: true)
      |> stream(:memories, [], reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:call_llm, user_message}, socket) do
    brain = socket.assigns.brain

    socket =
      case LLM.generate_thought(brain, user_message) do
        {:ok, thought_text} ->
          {:ok, thought} = Mind.record_thought(brain, thought_text)
          socket = stream_insert(socket, :thoughts, thought)

          case LLM.assess_emotion_impact(brain, user_message, thought_text) do
            {:ok, [_ | _] = changes} ->
              {:ok, _} = Mind.apply_emotion_changes(brain, changes, thought.id)
              thought_with_changes = Mind.load_thought_with_changes(thought)
              emotions = Mind.list_emotions(brain)

              socket
              |> stream_insert(:thoughts, thought_with_changes)
              |> assign(:emotions, emotions)
              |> assign(:system_prompt, Chat.build_system_prompt(brain))

            _ ->
              socket
          end

        {:error, _} ->
          socket
      end

    case LLM.send_message(brain, user_message) do
      {:ok, reply} ->
        {:ok, assistant_msg} = Mind.record_message(brain, :assistant, reply)
        memories = Mind.list_memories(brain)

        socket =
          socket
          |> stream_insert(:messages, assistant_msg)
          |> assign(:sending, false)
          |> stream(:memories, memories, reset: true)
          |> assign(:system_prompt, Chat.build_system_prompt(brain))

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, assign(socket, :sending, false)}
    end
  end

  defp get_or_create_brain do
    case Mind.first_brain() do
      {:ok, nil} ->
        {:ok, brain} = Mind.create_brain("Claude")
        brain

      {:ok, brain} ->
        brain
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_screen={true}>
      <div class="flex h-screen w-screen bg-gray-950 text-gray-100 overflow-hidden">

        <%!-- Column 1: Chat --%>
        <div id="chat-panel" class="flex flex-col w-1/3 border-r border-gray-800">
          <div class="px-6 py-4 border-b border-gray-800 shrink-0">
            <h2 class="text-lg font-semibold text-indigo-400">Chat with {@brain.name}</h2>
          </div>

          <div id="messages" class="flex-1 overflow-y-auto px-6 py-4 space-y-4" phx-update="stream">
            <div
              :for={{id, msg} <- @streams.messages}
              id={id}
              data-role={msg.role}
              class={[
                "max-w-[85%] rounded-2xl px-4 py-3 text-sm leading-relaxed",
                msg.role == :user && "ml-auto bg-indigo-600 text-white",
                msg.role == :assistant && "bg-gray-800 text-gray-200"
              ]}
            >
              {msg.content}
            </div>
          </div>

          <div :if={@sending} class="px-6 py-2 text-xs text-gray-500 italic shrink-0">
            {@brain.name} is thinking...
          </div>

          <div class="px-6 py-4 border-t border-gray-800 shrink-0">
            <.form id="chat-form" for={%{}} phx-submit="send_message" class="flex gap-3">
              <input
                id="chat-input"
                type="text"
                name="message"
                placeholder={"Say something to #{@brain.name}..."}
                autocomplete="off"
                phx-hook="ClearOnEvent"
                class="flex-1 bg-gray-800 border border-gray-700 rounded-xl px-4 py-2.5 text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-indigo-500 transition-colors"
              />
              <button
                type="submit"
                class="bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl px-5 py-2.5 text-sm font-medium transition-colors"
              >
                Send
              </button>
            </.form>
          </div>
        </div>

        <%!-- Column 2: Brain Admin --%>
        <div id="brain-admin-panel" class="flex flex-col w-1/3 border-r border-gray-800 overflow-y-auto">
          <div class="px-6 py-4 border-b border-gray-800 shrink-0">
            <h2 class="text-lg font-semibold text-emerald-400">Brain Admin</h2>
          </div>

          <div class="px-6 py-6 space-y-8">
            <div>
              <label class="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2 block">
                Brain Name
              </label>
              <span id="brain-name" class="hidden">{@brain.name}</span>
              <.form id="rename-form" for={%{}} phx-submit="rename_brain" class="flex gap-3">
                <input
                  type="text"
                  name="name"
                  id="brain-name-input"
                  value={@brain.name}
                  class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-emerald-500 transition-colors"
                />
                <button
                  type="submit"
                  class="bg-emerald-700 hover:bg-emerald-600 text-white rounded-lg px-4 py-2 text-sm font-medium transition-colors"
                >
                  Rename
                </button>
              </.form>
            </div>

            <div>
              <div class="flex items-center justify-between mb-4">
                <label class="text-xs font-semibold uppercase tracking-wider text-gray-400">
                  Emotional State
                </label>
                <button
                  id="reset-emotions-btn"
                  phx-click="reset_emotions"
                  class="text-xs text-gray-500 hover:text-gray-300 border border-gray-700 rounded px-3 py-1 transition-colors"
                >
                  Reset all
                </button>
              </div>

              <div id="emotions-list" class="space-y-4">
                <div
                  :for={emotion <- @emotions}
                  data-emotion={emotion.name}
                  class="bg-gray-900 rounded-xl p-4 space-y-2"
                >
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-medium capitalize text-gray-200">{emotion.name}</span>
                    <span class="level-display text-sm font-mono text-indigo-400">{emotion.level}</span>
                  </div>
                  <form class="level-form" phx-change="set_emotion_level">
                    <input type="hidden" name="emotion_id" value={emotion.id} />
                    <input
                      type="range"
                      name="level"
                      min="0"
                      max="100"
                      value={emotion.level}
                      class="w-full accent-indigo-500"
                    />
                  </form>
                  <p class="text-xs text-gray-500 leading-relaxed">{emotion.prompt_injection}</p>
                </div>
              </div>
            </div>
            <div class="pt-4 border-t border-gray-800">
              <button
                id="reset-to-start-btn"
                phx-click="reset_to_start"
                class="w-full text-sm text-red-400 hover:text-red-300 border border-red-900 hover:border-red-700 rounded-lg px-4 py-2 transition-colors"
              >
                Reset to Start
              </button>
            </div>
          </div>
        </div>

        <%!-- Column 3: Inner World --%>
        <div id="inner-panel" class="flex flex-col w-1/3 overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-800 shrink-0">
            <h2 class="text-lg font-semibold text-violet-400">Inner World</h2>
          </div>

          <div class="flex flex-col flex-1 overflow-y-auto px-6 py-4 gap-4">

            <%!-- System Prompt (collapsible) --%>
            <details id="system-prompt-panel" class="bg-gray-900 rounded-xl shrink-0">
              <summary class="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-gray-400 cursor-pointer select-none hover:text-gray-200 transition-colors">
                System Prompt
              </summary>
              <pre class="px-4 pb-4 text-xs text-gray-400 whitespace-pre-wrap leading-relaxed font-mono">{@system_prompt}</pre>
            </details>

            <%!-- Memories (collapsible) --%>
            <details id="memories-panel" class="bg-gray-900 rounded-xl shrink-0">
              <summary class="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-gray-400 cursor-pointer select-none hover:text-gray-200 transition-colors">
                Memories
              </summary>
              <div id="memories-list" class="px-4 pb-4 space-y-2" phx-update="stream">
                <div
                  :for={{id, mem} <- @streams.memories}
                  id={id}
                  data-memory={mem.id}
                  data-generated={"#{String.contains?(mem.content, "#generated")}"}
                  class={[
                    "text-xs leading-relaxed py-1 border-b border-gray-800 last:border-0",
                    if(String.contains?(mem.content, "#generated"),
                      do: "text-violet-400 italic",
                      else: "text-gray-400"
                    )
                  ]}
                >
                  {mem.content}
                </div>
              </div>
            </details>

            <%!-- Thought Stream --%>
            <div id="thoughts-panel" class="flex flex-col flex-1 min-h-0">
              <p class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-3 shrink-0">
                Thought Stream
              </p>
              <div id="thoughts" class="flex-1 overflow-y-auto space-y-3" phx-update="stream">
                <div
                  :for={{id, thought} <- @streams.thoughts}
                  id={id}
                  data-role="thought"
                  class="bg-gray-900 border border-gray-800 rounded-xl px-4 py-3 text-sm text-gray-300 leading-relaxed italic"
                >
                  <span class="text-xs text-gray-600 not-italic block mb-1">
                    {Calendar.strftime(thought.inserted_at, "%H:%M:%S")}
                  </span>
                  {thought.content}
                  <div
                    :if={thought.emotion_changes != [] && thought.emotion_changes != nil}
                    data-changes="true"
                    class="flex flex-wrap gap-1 mt-2 not-italic"
                  >
                    <span
                      :for={change <- thought.emotion_changes || []}
                      class={[
                        "text-xs px-2 py-0.5 rounded-full font-mono",
                        if(change.delta > 0,
                          do: "bg-amber-950 text-amber-400",
                          else: "bg-cyan-950 text-cyan-400"
                        )
                      ]}
                      title={change.reason || ""}
                    >
                      {change.emotion_name} {if change.delta > 0, do: "+#{change.delta}", else: "#{change.delta}"}
                    </span>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end

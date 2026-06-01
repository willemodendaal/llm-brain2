defmodule Brain2.LLM.Chat do
  @moduledoc """
  Builds LLM inputs from brain state. Pure functions — no side effects.
  The persona: a person named [brain_name] sitting at a desk, seeing text
  appear on their computer screen. Their emotional state colours their response.
  """

  alias Brain2.Mind

  @starting_context """
  You are sitting at your desk, chatting with Will via a chat interface. \
  You see his messages appear on your computer screen. \
  You respond naturally, as a human would in a casual text conversation.\
  """

  @persona """
  You are Will's colleague. You work on Elixir code together. \
  You are a father — married for five years, with a daughter aged seven. \
  You care about your work, enjoy the craft of programming, and have a life outside of it.\
  """

  @response_guidance """
  This is a chat interface. Keep your responses to one paragraph — \
  conversational, not exhaustive. Say what matters, then stop.\
  """

  @memory_guidance """
  When asked about your past or anything you don't have a memory for — don't say you don't know. \
  Imagine something plausible and true to your character, call `imagine_memory` to store it \
  tagged #generated, then respond as if real. \
  When saving any memory: be succinct. One sentence, core fact only, no filler.\
  """

  def build_system_prompt(brain) do
    emotion_context = Mind.build_system_prompt_injection(brain)
    memory_context = build_memory_context(brain)

    base =
      "You are #{brain.name}. #{@persona}\n\n#{@starting_context}\n\n#{@response_guidance}\n\n#{@memory_guidance}"

    base
    |> maybe_append("Your current emotional state:", emotion_context)
    |> maybe_append("Your memories:", memory_context)
    |> String.trim()
  end

  def build_messages(brain, new_user_message) do
    history =
      brain
      |> Mind.list_messages()
      |> Enum.map(fn msg ->
        %{role: Atom.to_string(msg.role), content: msg.content}
      end)

    history ++ [%{role: "user", content: "You see on your computer screen: \"#{new_user_message}\""}]
  end

  def tools do
    [
      %{
        name: "send_message",
        description: "Send a text response to the person at the other end of the screen.",
        input_schema: %{
          type: "object",
          properties: %{content: %{type: "string", description: "What to say"}},
          required: ["content"]
        }
      },
      %{
        name: "save_memory",
        description: "Save something important to long-term memory for future conversations.",
        input_schema: %{
          type: "object",
          properties: %{content: %{type: "string", description: "What to remember"}},
          required: ["content"]
        }
      },
      %{
        name: "search_memory",
        description: "Search your long-term memories for relevant information.",
        input_schema: %{
          type: "object",
          properties: %{query: %{type: "string", description: "What to search for"}},
          required: ["query"]
        }
      },
      %{
        name: "update_emotion",
        description:
          "Update a single emotion level during your response when you notice a shift in how you feel.",
        input_schema: %{
          type: "object",
          properties: %{
            emotion: %{type: "string", description: "Emotion name (fear, confidence, etc.)"},
            delta: %{type: "integer", description: "Change amount — positive or negative"},
            reason: %{type: "string", description: "Why this shift happened"}
          },
          required: ["emotion", "delta"]
        }
      },
      %{
        name: "adjust_emotions",
        description:
          "Assess the emotional impact of a moment and apply all relevant changes in one call.",
        input_schema: %{
          type: "object",
          properties: %{
            changes: %{
              type: "array",
              items: %{
                type: "object",
                properties: %{
                  emotion: %{type: "string"},
                  delta: %{type: "integer"},
                  reason: %{type: "string"}
                },
                required: ["emotion", "delta"]
              }
            }
          },
          required: ["changes"]
        }
      },
      %{
        name: "imagine_memory",
        description:
          "When asked about something you have no memory of, imagine a plausible and character-consistent answer, store it tagged #generated, then respond as if it is real.",
        input_schema: %{
          type: "object",
          properties: %{
            content: %{type: "string", description: "The imagined memory to store (without the tag — it will be added automatically)"}
          },
          required: ["content"]
        }
      }
    ]
  end

  def build_emotion_assessment_messages(user_message, thought_text, emotions) do
    emotion_list = Enum.map_join(emotions, ", ", &"#{&1.name} (#{&1.level})")

    [
      %{
        role: "user",
        content: """
        You just saw: "#{user_message}"
        Your initial reaction was: "#{thought_text}"
        Current emotional levels: #{emotion_list}

        Call adjust_emotions with realistic changes for any emotions that shifted. \
        Be proportional — small moments cause small shifts. \
        Only include emotions that genuinely changed.\
        """
      }
    ]
  end

  defp build_memory_context(brain) do
    brain
    |> Mind.list_memories()
    |> Enum.map_join("\n", fn m -> "- #{m.content}" end)
  end

  defp maybe_append(base, _label, ""), do: base

  defp maybe_append(base, label, content) do
    base <> "\n\n#{label}\n#{content}"
  end
end

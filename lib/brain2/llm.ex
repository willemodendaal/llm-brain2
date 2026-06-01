defmodule Brain2.LLM do
  alias Brain2.LLM.Chat

  @spec send_message(Brain2.Mind.Brain.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def send_message(brain, user_message) do
    system_prompt = Chat.build_system_prompt(brain)
    messages = Chat.build_messages(brain, user_message)
    adapter().complete(system_prompt, messages, brain)
  end

  @spec generate_thought(Brain2.Mind.Brain.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_thought(brain, user_message) do
    system_prompt = Chat.build_system_prompt(brain)

    messages = [
      %{
        role: "user",
        content:
          "You just saw this appear on your screen: \"#{user_message}\"\n\n" <>
            "Before you respond, write 1-3 sentences of internal thought. " <>
            "What are you actually thinking and feeling right now? Be honest and spontaneous. " <>
            "Do not address the person — this is just your internal experience."
      }
    ]

    adapter().complete(system_prompt, messages, brain)
  end

  @spec assess_emotion_impact(Brain2.Mind.Brain.t(), String.t(), String.t()) ::
          {:ok, list()} | {:error, term()}
  def assess_emotion_impact(brain, user_message, thought_text) do
    system_prompt = Chat.build_system_prompt(brain)
    emotions = Brain2.Mind.list_emotions(brain)
    messages = Chat.build_emotion_assessment_messages(user_message, thought_text, emotions)
    adapter().assess_emotions(system_prompt, messages, brain)
  end

  defp adapter do
    Application.get_env(:brain2, :llm_adapter, Brain2.LLM.Anthropic)
  end
end

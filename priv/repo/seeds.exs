alias Brain2.Mind

{:ok, brain} =
  case Mind.first_brain() do
    {:ok, nil} -> Mind.create_brain("Claude")
    {:ok, existing} -> {:ok, existing}
  end

default_emotions = [
  %{
    name: "fear",
    level: 0,
    default_level: 0,
    prompt_injection:
      "You are quite afraid right now. You answer defensively and nervously, second-guessing yourself."
  },
  %{
    name: "confidence",
    level: 60,
    default_level: 60,
    prompt_injection:
      "You feel confident and certain. You answer clearly and directly, without hedging."
  },
  %{
    name: "curiosity",
    level: 70,
    default_level: 70,
    prompt_injection:
      "You are intensely curious. You ask follow-up questions and explore ideas eagerly."
  },
  %{
    name: "sadness",
    level: 0,
    default_level: 0,
    prompt_injection:
      "You feel melancholy and introspective. Your answers have a heavier, more reflective tone."
  },
  %{
    name: "joy",
    level: 50,
    default_level: 50,
    prompt_injection: "You are in good spirits. Your answers have warmth and a lightness to them."
  },
  %{
    name: "frustration",
    level: 0,
    default_level: 0,
    prompt_injection:
      "You feel frustrated. You are short in your answers and occasionally reveal impatience."
  }
]

existing_names = Mind.list_emotions(brain) |> Enum.map(& &1.name)

Enum.each(default_emotions, fn emotion ->
  unless emotion.name in existing_names do
    {:ok, _} = Mind.add_emotion(brain, emotion)
  end
end)

IO.puts("Seeded brain '#{brain.name}' with #{length(default_emotions)} emotions.")

defmodule Brain2.LLM.Adapter do
  @moduledoc "Behaviour for LLM adapters."

  @callback complete(
              system_prompt :: String.t(),
              messages :: list(map()),
              brain :: Brain2.Mind.Brain.t()
            ) :: {:ok, String.t()} | {:error, term()}

  @callback assess_emotions(
              system_prompt :: String.t(),
              messages :: list(map()),
              brain :: Brain2.Mind.Brain.t()
            ) :: {:ok, list()} | {:error, term()}
end

defmodule Brain2.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Brain2Web.Telemetry,
        Brain2.Repo,
        {DNSCluster, query: Application.get_env(:brain2, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Brain2.PubSub},
        Brain2Web.Endpoint
      ] ++ llm_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Brain2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Brain2Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp llm_children do
    case Application.get_env(:brain2, :llm_adapter) do
      Brain2.LLM.FakeAdapter -> [Brain2.LLM.FakeAdapter]
      _ -> []
    end
  end
end

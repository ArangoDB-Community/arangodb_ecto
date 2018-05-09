defmodule ArangoDB.Ecto.Storage do
  @moduledoc false

  alias ArangoDB.Ecto.Utils

  @behaviour Ecto.Adapter.Storage

  @spec storage_up(options :: Keyword.t()) :: :ok | {:error, :already_up} | {:error, term}
  def storage_up(options) do
    repo = Keyword.fetch!(options, :repo)
    {:ok, _} = ArangoDB.Ecto.ensure_all_started(repo, :temporary)
    endpoint = Utils.get_endpoint(repo)
    response = Arangoex.Database.create(endpoint, %{name: endpoint.database_name})

    case response do
      {:ok, _} -> :ok
      {:error, %{"code" => 409}} -> {:error, :already_up}
      {:error, _} -> response
    end
  end

  @spec storage_down(options :: Keyword.t()) :: :ok | {:error, :already_down} | {:error, term}
  def storage_down(options) do
    repo = Keyword.fetch!(options, :repo)
    {:ok, _} = ArangoDB.Ecto.ensure_all_started(repo, :temporary)
    endpoint = Utils.get_endpoint(repo)
    response = Arangoex.Database.drop(endpoint, endpoint.database_name)

    case response do
      {:ok, _} -> :ok
      {:error, %{"code" => 404}} -> {:error, :already_down}
      {:error, _} -> response
    end
  end
end

defmodule ArangoDB.Ecto.Storage do
  @moduledoc false

  alias ArangoDB.Ecto.Utils

  @behaviour Ecto.Adapter.Storage

  @spec storage_up(options :: Keyword.t()) :: :ok | {:error, :already_up} | {:error, term}
  def storage_up(options) do
    repo = Keyword.fetch!(options, :repo)
    {:ok, _} = ArangoDB.Ecto.ensure_all_started(repo, :temporary)
    config = Utils.get_config(repo)
    response = Arango.Database.create(name: config[:database_name]) |> Arango.request(config)

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
    config = Utils.get_config(repo)
    response = Arango.Database.drop(config[:database_name]) |> Arango.request(config)

    case response do
      {:ok, _} -> :ok
      {:error, %{"code" => 404}} -> {:error, :already_down}
      {:error, _} -> response
    end
  end
end

defmodule ArangoDB.Ecto.Utils do
  @moduledoc false

  @spec get_endpoint(Ecto.Adapter.repo(), String.t() | nil) :: Arangoex.Endpoint.t()
  def get_endpoint(repo, prefix \\ nil) do
    config = repo.config()
    database = prefix || Keyword.get(config, :database) || Keyword.get(config, :database_name)

    config =
      config
      |> Keyword.put(:database_name, database)

    struct(Arangoex.Endpoint, config)
  end
end

defmodule ArangoDB.Ecto.Utils do
  @moduledoc false

  @spec get_config(Ecto.Repo.t, String.t() | nil) :: Keyword.t
  def get_config(repo, prefix \\ nil) do
    config = repo.config()
    database = prefix || Keyword.get(config, :database) || Keyword.get(config, :database_name)

    config
    |> Keyword.put(:database_name, database)
  end
end

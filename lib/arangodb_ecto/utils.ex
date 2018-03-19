defmodule ArangoDB.Ecto.Utils do
  @moduledoc false

  @spec get_endpoint(Ecto.Adapter.repo, String.t | nil) :: Arangoex.Endpoint.t
  def get_endpoint(repo, prefix \\ nil) do
    config = repo.config
    config = if prefix == nil,
      do: config,
      else: Keyword.put(config, :database_name, prefix)
    
    struct(Arangoex.Endpoint, config)
  end
end
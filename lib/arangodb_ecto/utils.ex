defmodule ArangoDB.Ecto.Utils do
  @moduledoc false

  @spec get_endpoint(Ecto.Adapter.repo, String.t | nil) :: Arangoex.Endpoint.t
  def get_endpoint(repo, prefix \\ nil)
  def get_endpoint(repo, nil), do: repo.__endpoint__
  def get_endpoint(repo, prefix) when is_binary(prefix),
    do: %Arangoex.Endpoint{repo.__endpoint__ | :database_name => prefix}
end
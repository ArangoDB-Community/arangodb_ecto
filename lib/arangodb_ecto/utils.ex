defmodule ArangoDB.Ecto.Utils do
  @moduledoc false

  def get_endpoint(repo, opts, prefix \\ nil) do
    conf = repo.__config__
    endpoint = Keyword.get(opts, :endpoint, conf[:endpoint])
    case prefix do
      nil -> endpoint
      db when is_binary(db) -> %Arangoex.Endpoint{endpoint | :database_name => db}
    end
    #TODO: use options?
  end
end
defmodule ArangoDB.Ecto.Migration do
  @moduledoc false

  require Logger
  alias ArangoDB.Ecto.Utils

  @behaviour Ecto.Adapter.Migration

  def supports_ddl_transaction?, do: false

  def execute_ddl(repo, command, opts) do
    endpoint = Utils.get_endpoint(repo, opts)
    not_exists_cmd = is_not_exists(command)
    result = execute(endpoint, command, opts)
    case result do
      {:ok, _} -> :ok
      {:error, %{"code" => 409}} when not_exists_cmd -> :ok # collection/index already exists
      {:error, err} -> raise Ecto.MigrationError, message: err["errorMessage"]
    end
  end

  defp is_not_exists({:create_if_not_exists, _}), do: true
  defp is_not_exists({:create_if_not_exists, _, _}), do: true
  defp is_not_exists(_), do: false

  defp execute(endpoint, {cmd, %Ecto.Migration.Table{name: name}, _}, _opts)
      when cmd in [:create, :create_if_not_exists]
  do
    # TODO: use table options
    Arangoex.Collection.create(endpoint, %Arangoex.Collection{name: name})
  end

  defp execute(endpoint, {cmd, %Ecto.Migration.Index{table: collection, columns: fields} = index}, options)
      when cmd in [:create, :create_if_not_exists]
  do
    body = make_index(index, options)
    Arangoex.Index.create_general(endpoint, collection, Map.put(body, :fields, fields))
  end

  defp execute(_, {:alter, _, _}, options) do
    if options[:log], do: Logger.warn "ALTER command has no effect in ArangoDB."
    {:ok, nil}
  end

  defp execute(_, {cmd, _, _}, _) do
    raise "{inspect __MODULE__}: unspported DDL operation #{inspect cmd}"
  end

  #
  # Helpers
  #

  defp make_index(%{where: where}, _) when where != nil,
    do: raise "{inspect __MODULE__} does not support conditional indices."

  # default to :hash when no index type is specified
  defp make_index(%{using: nil} = index, options),
    do: make_index(%Ecto.Migration.Index{index | using: :hash}, options)

  defp make_index(%{using: :hash, unique: unique}, options) do
    %{type: "hash",
      unique: unique,
      sparse: Keyword.get(options, :sparse, false)}
  end

  defp make_index(%{using: :skip_list, unique: unique}, options) do
    %{type: "skiplist",
      unique: unique,
      sparse: Keyword.get(options, :sparse, false)}
  end

  defp make_index(%{using: :fulltext, unique: unique}, options) do
    if (unique), do: raise "Fulltext indices cannot be unique."
    %{type: "fulltext",
      minLength: Keyword.get(options, :min_length, nil)}
  end
end
defmodule ArangoDB.Ecto.Migration do
  @moduledoc """
  You can create and drop databases using `mix ecto.create` and `mix.ecto.drop`.

  Migrations will work for creating tables (map to collections in ArangoDB) and
  indexes. Column/field specifications are not supported by ArangoDB and will be
  ommited when executing the migration.

  This adapter provides support for `:hash`, `:skip_list` and `:fulltext` indexes, e.g.:
  ```elixir
  create index(:posts, [:visits], using: :skip_list)
  ```
  """

  require Logger
  alias ArangoDB.Ecto.Utils

  @behaviour Ecto.Adapter.Migration

  @doc """
  ArangoDB does not support DDL transactions, thus always returns `false`.
  """
  def supports_ddl_transaction?, do: false

  @doc """
  Executes migration commands.
  """
  def execute_ddl(repo, command, opts) do
    config = Utils.get_config(repo)
    not_exists_cmd = is_not_exists(command)
    result = execute(config, command, opts)

    case result do
      {:ok, _} ->
        :ok

      # collection/index already exists
      {:error, %{"code" => 409}} when not_exists_cmd ->
        :ok

      {:error, err} ->
        raise Ecto.MigrationError, message: err["errorMessage"]
    end
  end

  defp is_not_exists({:create_if_not_exists, _}), do: true
  defp is_not_exists({:create_if_not_exists, _, _}), do: true
  defp is_not_exists(_), do: false

  defp execute(config, {cmd, %Ecto.Migration.Table{name: name, options: options}, _}, _opts)
       when cmd in [:create, :create_if_not_exists] do
    # TODO: use table options
    collection_type =
      case options do
        # document collection
        nil ->
          2

        # edge collection
        "edge" ->
          3

        _ ->
          raise "Invalid options value `#{options}`."
      end

    Arango.Collection.create(%Arango.Collection{name: name, type: collection_type})
    |> Arango.Request.perform(config)
  end

  defp execute(config, {cmd, %Ecto.Migration.Table{name: name}}, _opts)
       when cmd in [:drop, :drop_if_exists] do
    Arango.Collection.drop(%Arango.Collection{name: name})
    |> Arango.Request.perform(config)
  end

  defp execute(
         config,
         {cmd, %Ecto.Migration.Index{table: collection, columns: fields} = index},
         _opts
       )
       when cmd in [:create, :create_if_not_exists] do
    body = make_index(index)
    Arango.Index.create_general(collection, Map.put(body, :fields, fields))
    |> Arango.Request.perform(config)
  end

  defp execute(
         config,
         {cmd, %Ecto.Migration.Index{table: collection, columns: fields} = index},
         _opts
       )
       when cmd in [:drop, :drop_if_exists] do
    body =
      make_index(index)
      |> Map.put(:fields, fields)
      |> Jason.encode!()
      |> Jason.decode!()
      |> MapSet.new()

    {:ok, %{"error" => false, "indexes" => indexes}} =
      Arango.Index.indexes(collection)
      |> Arango.Request.perform(config)

    matching_index = Enum.filter(indexes, &MapSet.subset?(body, MapSet.new(&1)))

    case {cmd, matching_index} do
      {_, [index]} -> Arango.Index.delete(index["id"]) |> Arango.Request.perform(config)
      {:drop_if_exists, []} -> :ok
      {:drop, []} -> raise "No index found matching #{inspect(index)}"
    end
  end

  defp execute(_, {:alter, _, _}, options) do
    if options[:log], do: Logger.warn("ALTER command has no effect in ArangoDB.")
    {:ok, nil}
  end

  defp execute(_, cmd, _) do
    raise "#{inspect(__MODULE__)}: unspported DDL operation #{inspect(cmd)}"
  end

  #
  # Helpers
  #

  defp make_index(%{where: where}) when where != nil,
    do: raise("{inspect __MODULE__} does not support conditional indices.")

  # default to :hash when no index type is specified
  defp make_index(%{using: nil} = index),
    do: make_index(%Ecto.Migration.Index{index | using: :hash}, [])

  defp make_index(%{using: type} = index) when is_atom(type), do: make_index(index, [])

  defp make_index(%{using: {type, opts}} = index) when is_atom(type) and is_list(opts),
    do: make_index(%{index | using: type}, opts)

  defp make_index(%{using: :hash, unique: unique}, options) do
    %{type: "hash", unique: unique, sparse: Keyword.get(options, :sparse, false)}
  end

  defp make_index(%{using: :skip_list, unique: unique}, options) do
    %{type: "skiplist", unique: unique, sparse: Keyword.get(options, :sparse, false)}
  end

  defp make_index(%{using: :fulltext, unique: unique}, options) do
    if unique, do: raise("Fulltext indices cannot be unique.")
    %{type: "fulltext", minLength: Keyword.get(options, :min_length, nil)}
  end
end

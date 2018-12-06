defmodule ArangoDB.Ecto do
  @moduledoc """
  Ecto 2.x adapter for ArangoDB.

  At the moment the `from`, `where`, `order_by`, `limit`
  `offset` and `select` clauses are supported.
  """

  alias ArangoDB.Ecto.Utils

  def truncate(repo, coll) do
    result =
      Arango.Collection.truncate(%Arango.Collection{name: coll})
      |> Arango.Request.perform(Utils.get_config(repo))

    case result do
      {:ok, _} -> :ok
      {:error, _} -> result
    end
  end

  def query(repo, aql, vars \\ []) do
    res = ArangoDB.Ecto.Adapter.exec_query!(repo, aql, vars)
    {:ok, res}
  rescue
    e in RuntimeError -> {:error, e.message}
  end

  def query!(repo, aql, vars \\ []) do
    ArangoDB.Ecto.Adapter.exec_query!(repo, aql, vars)
  end

  @behaviour Ecto.Adapter

  # Delegates for Adapter behaviour

  defmacro __before_compile__(_env) do
  end

  defdelegate autogenerate(field_type), to: ArangoDB.Ecto.Adapter
  defdelegate child_spec(repo, options), to: ArangoDB.Ecto.Adapter
  defdelegate delete(repo, schema_meta, filters, options), to: ArangoDB.Ecto.Adapter
  defdelegate dumpers(primitive_type, ecto_type), to: ArangoDB.Ecto.Adapter
  defdelegate ensure_all_started(repo, type), to: ArangoDB.Ecto.Adapter

  defdelegate execute(repo, query_meta, query, params, process, options),
    to: ArangoDB.Ecto.Adapter

  defdelegate insert(repo, schema_meta, fields, on_conflict, returning, options),
    to: ArangoDB.Ecto.Adapter

  defdelegate insert_all(repo, schema_meta, header, list, on_conflict, returning, options),
    to: ArangoDB.Ecto.Adapter

  defdelegate loaders(primitive_type, ecto_type), to: ArangoDB.Ecto.Adapter
  defdelegate prepare(atom, query), to: ArangoDB.Ecto.Adapter

  defdelegate update(repo, schema_meta, fields, filters, returning, options),
    to: ArangoDB.Ecto.Adapter

  @behaviour Ecto.Adapter.Migration

  # Delegates for Migration behaviour

  defdelegate supports_ddl_transaction?, to: ArangoDB.Ecto.Migration
  defdelegate execute_ddl(repo, ddl, opts), to: ArangoDB.Ecto.Migration

  @behaviour Ecto.Adapter.Storage

  # Delegates for Storage behaviour

  defdelegate storage_up(options), to: ArangoDB.Ecto.Storage
  defdelegate storage_down(options), to: ArangoDB.Ecto.Storage
end

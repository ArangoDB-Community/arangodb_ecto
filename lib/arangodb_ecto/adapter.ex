defmodule ArangoDB.Ecto.Adapter do
  @moduledoc false

  require Logger
  alias ArangoDB.Ecto.Utils

  @type query_meta :: Ecto.Adapter.query_meta
  @type schema_meta :: Ecto.Adapter.schema_meta
  @type source :: Ecto.Adapter.source
  @type fields :: Ecto.Adapter.fields
  @type filters :: Ecto.Adapter.filters
  @type constraints :: Ecto.Adapter.constraints
  @type returning :: Ecto.Adapter.returning
  @type prepared :: Ecto.Adapter.prepared
  @type cached :: Ecto.Adapter.cached
  @type process :: Ecto.Adapter.process
  @type autogenerate_id :: Ecto.Adapter.autogenerate_id
  @type on_conflict :: Ecto.Adapter.on_conflict

  @typep repo :: Ecto.Adapter.repo
  @typep options :: Ecto.Adapter.options

  # Adapter callbacks

  def ensure_all_started(_repo, type),
    do: Application.ensure_all_started(:arangodb_ecto, type)

  def child_spec(_repo, _opts),
    do: Supervisor.Spec.supervisor(Supervisor, [[], [strategy: :one_for_one]])

  @spec autogenerate(field_type :: :id | :binary_id | :embed_id) :: term | nil | no_return
  def autogenerate(:id),        do: raise "Autogeneration of :id type is not supported."
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: nil

  @spec loaders(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
          [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def loaders(:uuid, Ecto.UUID), do: [&{:ok, &1}]
  def loaders(:date, _type), do: [&load_date/1]
  def loaders(:utc_datetime, _type), do: [&load_utc_datetime/1]
  def loaders(:naive_datetime, _type), do: [&NaiveDateTime.from_iso8601/1]
  def loaders(_primitive, type), do: [type]

  @spec dumpers(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
          [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def dumpers(:uuid, Ecto.UUID), do: [&{:ok, &1}]
  def dumpers(:date, _type),
    do: [fn d -> {:ok, Date.to_iso8601(d)} end]
  def dumpers(:utc_datetime, _type),
    do: [fn %DateTime{} = dt -> {:ok, DateTime.to_iso8601(dt)} end]
  def dumpers(:naive_datetime, _type),
    do: [fn %NaiveDateTime{} = dt -> {:ok, NaiveDateTime.to_iso8601(dt)} end]
  def dumpers(_primitive, type), do: [type]

  @spec prepare(atom :: :all | :update_all | :delete_all, query :: Ecto.Query.t) ::
          {:cache, prepared} | {:nocache, prepared}
  def prepare(cmd, query) do
    aql = apply(ArangoDB.Ecto.Query, cmd, [query])
    {:nocache, {cmd, aql}}
  end

  @spec execute(repo, query_meta, query, params :: list(), process | nil, options) :: result when
          result: {integer, [[term]] | nil} | no_return,
          query: {:nocache, prepared} |
                 {:cached, (prepared -> :ok), cached} |
                 {:cache, (cached -> :ok), prepared}
  def execute(repo, %{fields: fields, prefix: prefix}, {:nocache, {cmd, aql}}, params, process, options) do
    Logger.debug(aql)
    cursor = make_cursor(aql, params)
    # TODO - apply Arango specific options
    Utils.get_endpoint(repo, options, prefix)
    |> Arangoex.Cursor.cursor_create(cursor)
    |> to_result(cmd, {fields, process})
  end

  @spec insert_all(repo, schema_meta, header :: [atom], [fields], on_conflict, returning, options) ::
          {integer, [[term]] | nil} | no_return
  def insert_all(repo, %{source: {prefix, collection}}, _header, fields, _on_conflict, returning, options) do
    docs = build_documents(fields)
    return_new = Enum.any?(returning, &not &1 in [:_id, :_key, :_rev])
    opts = if return_new,
      do: [returnNew: true],
      else: []
    # TODO - apply Arango specific options
    Logger.debug("Inserting documents #{inspect docs} into collection #{collection}")
    Utils.get_endpoint(repo, options, prefix)
    |> Arangoex.Document.create(%Arangoex.Collection{name: collection}, docs, opts)
    |> to_result(:insert_all, returning)
  end

  @spec insert(repo, schema_meta, fields, on_conflict, returning, options) ::
          {:ok, fields} | {:invalid, constraints} | no_return
  def insert(repo, %{source: {prefix, collection}}, fields, _on_conflict, returning, options) do
    document = Enum.into(fields, %{})
    Logger.debug("Inserting document #{inspect document} into collection #{collection}")
    # TODO - apply Arango specific options
    Utils.get_endpoint(repo, options, prefix)
    |> Arangoex.Document.create(%Arangoex.Collection{name: collection}, document, [])
    |> to_result(:insert, returning)
  end

  @spec delete(repo, schema_meta, filters, options) ::
          {:ok, fields} | {:invalid, constraints} | {:error, :stale} | no_return
  def delete(repo, %{source: {prefix, collection}}, [{:_key, key}], options) do
    Logger.debug("Deleting document with key #{key} from collection #{collection}")
    doc = %{_key: key, _id: "#{collection}/#{key}"}
    # TODO - apply Arango specific options
    Utils.get_endpoint(repo, options, prefix)
    |> Arangoex.Document.delete(doc)
    |> to_result(:delete, [])
  end

  def delete(_repo, _schema_meta, _filters, _options) do
    raise "delete with multiple filters is not yet implemented"
  end

  @spec update(repo, schema_meta, fields, filters, returning, options) ::
          {:ok, fields} | {:invalid, constraints} | {:error, :stale} | no_return
  def update(repo, %{source: {prefix, collection}}, fields, [{:_key, key}], returning, options) do
    document = Enum.into(fields, %{})
    old = %{_key: key, _id: "#{collection}/#{key}"}
    Logger.debug("Updating document #{inspect old} to: #{inspect document}")
    # TODO - apply Arango specific options
    Utils.get_endpoint(repo, options, prefix)
    |> Arangoex.Document.update(old, document, [])
    |> to_result(:update, returning)
  end
  def update(_repo, _schema_meta, _fields, _filters, _returning, _options) do
    raise "update with multiple filters is not yet implemented"
  end

  #
  # Helpers
  #

  #
  # insert / update

  defp to_result({:ok, doc}, cmd, fields) when cmd in [:insert, :update],
    do: {:ok, Enum.map(fields, & {&1, Map.get(doc, &1)})}

  #
  # delete

  defp to_result({:ok, _}, :delete, _), do:
    {:ok, []}

  #
  # all

  defp to_result({:ok, %{"result" => []}}, :all, _),
    do: {0, []}
  defp to_result({:ok, %{"hasMore" => true}}, :all, _),
    do: raise "Query resulted in more entries than could be returned in a single batch, but cursors are not yet supported."
  defp to_result({:ok, %{"result" => docs}}, :all, {fields, process}),
    do: {length(docs), Enum.map(docs, &process_document(&1, fields, process))}

  #
  # update_all / delete_all

  defp to_result({:ok, %{"extra" => %{"stats" => %{"writesExecuted" => count}}, "result" => []}}, cmd, _) when cmd in [:update_all, :delete_all],
    do: {count, nil}
  defp to_result({:ok, %{"extra" => %{"stats" => %{"writesExecuted" => count}}, "result" => docs}}, cmd, {fields, process})  when cmd in [:update_all, :delete_all],
    do: {count, Enum.map(docs, &process_document(&1, fields, process))}

  #
  # insert_all

  defp to_result(docs, :insert_all, returning) when is_list(docs),
    do: handle_insert_result(docs, returning)

  #
  # errors

  defp to_result({:error, %{"code" => 409}}, _, _),
    do: {:invalid, [unique: "constraint violated"]}

  defp to_result({:error, err}, _, _),
    do: raise err["errorMessage"]

  defp build_documents(fields) when is_list(fields) do
    Enum.map(fields, fn
      %{} = doc -> doc
      doc when is_list(doc) -> Enum.into(doc, %{})
     end)
  end

  defp handle_insert_result(docs, returning) when is_list(docs) do
    errors = Enum.filter_map(docs, &match?({:error, _}, &1), fn {_, err} -> err["errorMessage"] end)
    if (errors != []) do
      raise Enum.join(["Errors occured when inserting documents: " | errors], "\n")
    else
      process_documents(docs, returning)
    end
  end

  defp process_documents(docs, []),
    do: {length(docs), nil}

  defp process_documents(docs, fields) do
    {length(docs), Enum.map(docs, fn
                                   {:ok, {_ref, doc}} -> process_document(doc, fields)
                                   {:ok, ref} -> process_document(ref, fields)
                                  end)}
  end

  defp process_document(document, fields),
    do: process_document(document, fields, fn _, v, _ -> v end)

  defp process_document(doc, fields, process) do
    fields
    |> Enum.map(&process_field(&1, doc, process))
  end

  defp process_field(field, doc, process) when is_atom(field),
    do: process.(field, Map.get(doc, Atom.to_string(field)), nil)
  defp process_field({{:., _, [{:&, _, _}, field_name]}, _, []} = field, doc, process),
   do: process.(field, Map.get(doc, Atom.to_string(field_name)), nil)
  defp process_field({:&, _, [_, fields, _]} = field, doc, process) do
    string_fields = Enum.map(fields, &to_string/1)
    doc = Enum.filter_map(doc,
                          fn {n, _} -> n in string_fields end,
                          fn {n,v} -> {String.to_atom(n), v} end)
      |> Enum.into(%{})
    process.(field, doc, nil)
  end

  defp make_cursor(aql, []),
    do: %Arangoex.Cursor.Cursor{query: aql}
  defp make_cursor(aql, params) do
    vars = params
      |> Enum.with_index(1)
      |> Enum.map(fn {value, idx} -> {Integer.to_string(idx), value} end)
    %Arangoex.Cursor.Cursor{query: aql, bind_vars: vars}
  end

  defp load_date(d) do
    case Date.from_iso8601(d) do
      {:ok, res} -> {:ok, res}
      {:error, _} -> :error
    end
  end

  defp load_utc_datetime(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, res, _} -> {:ok, res}
      {:error, _} -> :error
    end
  end
end
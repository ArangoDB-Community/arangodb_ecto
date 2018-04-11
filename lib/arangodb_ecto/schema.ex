defmodule ArangoDB.Ecto.Schema do
  @moduledoc """
  This is a little helper module to releave you of always having to specify the primary key.

  In ArangoDB, every document is equipped with a `_key` field that is usually initialized
  by the server. This `_key` field is the one and only primary key - you cannot define your
  own.

  By using this module instead of `Ecto.Schema`, ArangoDB's `_key` is translated into
  the Ecto default primary key name of `id`.

  If you want to use the ArangoDB `_key`, specify the option `arango_key: true`:
  `use ArangoDB.Ecto.Schema, arango_key: true`

  `@primary_key` attribute defined:
  ```elixir
  @primary_key {:id, :binary_id, autogenerate: true, source: :_key}
  ```
  """

  defmacro __using__(arango_key: true) do
    quote do
      use Ecto.Schema

      @primary_key {:_key, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true, source: :_key}
      @foreign_key_type :binary_id
    end
  end
end

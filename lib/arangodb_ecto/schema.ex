defmodule ArangoDB.Ecto.Schema do
  @moduledoc """
  This is a little helper module to releave you of always having to specify the primary key.

  In ArangoDB, every document is equipped with a `_key` field that is usually initialized
  by the server. This `_key` field is the one and only primary key - you cannot define your
  own.

  By using this module instead of `Ecto.Schema` you automatically get the according
  `@primary_key` attribute defined:
  ```elixir
  @primary_key {:_key, :binary_id, autogenerate: true}
  ```
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      @primary_key {:_key, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
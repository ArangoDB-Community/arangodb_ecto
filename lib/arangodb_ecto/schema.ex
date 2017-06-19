defmodule ArangoDB.Ecto.Schema do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      @primary_key {:_key, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
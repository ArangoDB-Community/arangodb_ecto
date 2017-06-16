defmodule ArangoDB.Ecto do
  @moduledoc """
  Ecto adapter for ArangoDB.
  """

  defdelegate autogenerate(field_type), to: ArangoDB.Ecto.Adapter
  defdelegate loaders(primitive_type, ecto_type), to: ArangoDB.Ecto.Adapter
  defdelegate dumpers(primitive_type, ecto_type), to: ArangoDB.Ecto.Adapter
end

defmodule ArangoDB.Ecto.Adapter do
  @moduledoc false

  @behaviour Ecto.Adapter

  # Adapter callbacks

  @spec autogenerate(field_type :: :id | :binary_id | :embed_id) :: term | nil | no_return
  def autogenerate(:id),        do: raise "Autogeneration of :id type is not supported."
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: nil

  @spec loaders(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
        [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def loaders(primitive, type), do: [type]

  @spec dumpers(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t) ::
        [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def dumpers(primitive, type), do: [type]
end
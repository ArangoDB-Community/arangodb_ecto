defmodule Ecto.Integration.User do
  @moduledoc """
  This module is used to test:

    * UTC Timestamps
    * Relationships
    * Dependent callbacks

  """

  use ArangoDB.Ecto.Schema

  @timestamps_opts [usec: true]
  schema "users" do
    field :name
    field :age, :integer
    field :hobbies, {:array, :string}
    has_many :comments, Ecto.Integration.Comment, foreign_key: :author_id
    has_many :posts, Ecto.Integration.Post, foreign_key: :author_id
    timestamps type: :utc_datetime
  end
end

defmodule Ecto.Integration.Post do
 @moduledoc """
  This module is used to test:

    * Overall functionality
    * Overall types
    * Non-null timestamps
    * Relationships
    * Dependent callbacks

  """

  use ArangoDB.Ecto.Schema

  @timestamps_opts [usec: true]
  schema "posts" do
    field :title, :string
    field :counter, :integer
    field :text, :binary
    field :temp, :string, default: "temp", virtual: true
    field :public, :boolean, default: true
    field :cost, :decimal
    field :visits, :integer
    field :intensity, :float
    field :uuid, Ecto.UUID, autogenerate: true
    field :timeuuid, :binary_id
    field :meta, :map
    field :links, {:map, :string}
    field :posted, :date
    field :ip, :binary
    field :modification_date, :date
    field :modification_time, :time
    has_many :comments, Ecto.Integration.Comment
    belongs_to :author, Ecto.Integration.User
    timestamps()
  end

  def changeset(schema, params) do
    Ecto.Changeset.cast(schema, params,
      ~w(title counter text temp public cost visits intensity uuid meta posted))
  end
end

defmodule Ecto.Integration.Comment do
  @moduledoc """
  This module is used to test:
    * Optimistic lock
    * Relationships
    * Dependent callbacks
  """
  use ArangoDB.Ecto.Schema

  schema "comments" do
    field :_rev, :binary, read_after_writes: true
    field :text, :string
    belongs_to :post, Ecto.Integration.Post
    belongs_to :author, Ecto.Integration.User
    #has_one :post_permalink, through: [:post, :permalink]
  end

  def changeset(schema, params) do
    Ecto.Changeset.cast(schema, params, [:text])
  end
end

defmodule Ecto.Integration.Custom do
  use ArangoDB.Ecto.Schema

  schema "customs" do
    field :_id, :binary_id, read_after_writes: true
    field :uuid, Ecto.UUID
    many_to_many :customs, Ecto.Integration.Custom,
      join_through: "customs_customs",
      join_keys: [_from: :_id, _to: :_id],
      on_delete: :delete_all,
      on_replace: :delete
  end
end

defmodule Ecto.Integration.Tag do
  @moduledoc """
  This module is used to test:

    * The array type
    * Embedding many schemas (uses array)

  """
  use ArangoDB.Ecto.Schema

  schema "tags" do
    field :ints, {:array, :integer}
    field :uuids, {:array, Ecto.UUID}
    embeds_many :items, Ecto.Integration.Item
  end
end

defmodule Ecto.Integration.Item do
  @moduledoc """
  This module is used to test:

    * Embedding

  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :price, :integer
    field :valid_at, :date
  end
end

defmodule Ecto.Integration.Order do
  @moduledoc """
  This module is used to test:

    * Embedding one schema

  """
  use ArangoDB.Ecto.Schema

  schema "orders" do
    embeds_one :item, Ecto.Integration.Item
  end
end

defmodule Ecto.Integration.Doc do
  @moduledoc """
  This module is used to test:

    * Using Arango's `_key` instead of Ecto's `id`

  """
  use ArangoDB.Ecto.Schema, arango_key: true

  schema "docs" do
    field :content, :string
  end
end

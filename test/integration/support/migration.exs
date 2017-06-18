defmodule Ecto.Integration.Migration do
  use Ecto.Migration

  def change do
    create table(:users, comment: "users table", primary_key: false) do
      #add :name, :text
      #add :hobbies, {:array, :string}
      #timestamps()
    end

    create table(:posts) do
      #add :title, :text
      #add :counter, :integer
      #add :text, :binary
      #add :uuid, :uuid
      #add :timeuuid, :timeuuid
      #add :meta, :map
      #add :links, {:map, :string}
      #add :public, :boolean
      #add :cost, :decimal
      #add :visits, :integer
      #add :intensity, :float
      #add :author_id, :integer
      #add :posted, :date
      #timestamps()
    end
    create index(:posts, [:visits], using: :skip_list)
    create index(:posts, [:text], using: :fulltext)

    create table(:comments) do
      #add :text, :string, size: 100
      #add :post_id, references(:posts)
      #add :author_id, references(:users)
    end

    create table(:customs) do
      #add :uuid, :uuid
    end
    create unique_index(:customs, [:uuid])
  end
end

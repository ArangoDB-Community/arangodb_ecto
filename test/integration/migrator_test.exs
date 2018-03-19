Code.require_file "../../deps/ecto/integration_test/cases/migrator.exs", __DIR__

defmodule ArangoDB.Ecto.Integration.MigratorTest do

  use Ecto.Integration.Case

  alias Ecto.Integration.PoolRepo
  alias Ecto.Migration.SchemaMigration
  
  import Ecto.Migrator

  setup do
    PoolRepo.delete_all(SchemaMigration)
    :ok
  end

  defmodule CollectionMigration do
    use Ecto.Migration

    def change do
      create table(:dummy_collection)
    end
  end

  defmodule IndexMigration do
    use Ecto.Migration

    def change do
      create index(:posts, :author_id)
    end
  end

  test "run and rollback collection migration" do
    endpoint = ArangoDB.Ecto.Utils.get_endpoint(PoolRepo)

    assert up(PoolRepo, 20100906120000, CollectionMigration, log: false) == :ok
    {:ok, collections} = Arangoex.Collection.collections(endpoint)
    assert [_] = collections |> Enum.filter(&match?(%{name: "dummy_collection"}, &1))

    assert down(PoolRepo, 20100906120000, CollectionMigration, log: false) == :ok
    {:ok, collections} = Arangoex.Collection.collections(endpoint)
    assert [] = collections |> Enum.filter(&match?(%{name: "dummy_collection"}, &1))
  end

  test "run and rollback index migration" do
    endpoint = ArangoDB.Ecto.Utils.get_endpoint(PoolRepo)

    assert up(PoolRepo, 20100906120000, IndexMigration, log: false) == :ok
    {:ok, %{"error" => false, "indexes" => indexes}} = Arangoex.Index.indexes(endpoint, "posts")
    assert [_index] = indexes |> Enum.filter(&match?(%{"fields" => ["author_id"]}, &1))

    assert down(PoolRepo, 20100906120000, IndexMigration, log: false) == :ok
    {:ok, %{"error" => false, "indexes" => indexes}} = Arangoex.Index.indexes(endpoint, "posts")
    assert [] = indexes |> Enum.filter(&match?(%{"fields" => ["author_id"]}, &1))
  end
end
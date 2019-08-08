Code.require_file("../../deps/ecto/integration_test/cases/migrator.exs", __DIR__)

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
      create(table(:dummy_collection))
    end
  end

  defmodule IndexMigration do
    use Ecto.Migration

    def change do
      create(index(:posts, :author_id))
    end
  end

  test "run and rollback collection migration" do
    config = ArangoDB.Ecto.Utils.get_config(PoolRepo)

    assert up(PoolRepo, 20_100_906_120_000, CollectionMigration, log: false) == :ok
    {:ok, collections} = Arango.Collection.collections() |> Arango.request(config)
    assert [_] = collections |> Enum.filter(&match?(%{name: "dummy_collection"}, &1))

    assert down(PoolRepo, 20_100_906_120_000, CollectionMigration, log: false) == :ok
    {:ok, collections} = Arango.Collection.collections() |> Arango.request(config)
    assert [] = collections |> Enum.filter(&match?(%{name: "dummy_collection"}, &1))
  end

  test "run and rollback index migration" do
    config = ArangoDB.Ecto.Utils.get_config(PoolRepo)

    assert up(PoolRepo, 20_100_906_120_000, IndexMigration, log: false) == :ok
    {:ok, %{"error" => false, "indexes" => indexes}} = Arango.Index.indexes("posts") |> Arango.request(config)
    assert [_index] = indexes |> Enum.filter(&match?(%{"fields" => ["author_id"]}, &1))

    assert down(PoolRepo, 20_100_906_120_000, IndexMigration, log: false) == :ok
    {:ok, %{"error" => false, "indexes" => indexes}} = Arango.Index.indexes("posts") |> Arango.request(config)
    assert [] = indexes |> Enum.filter(&match?(%{"fields" => ["author_id"]}, &1))
  end
end

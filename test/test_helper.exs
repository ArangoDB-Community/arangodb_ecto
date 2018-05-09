ExUnit.start()

Application.put_env(:ecto, :primary_key_type, :binary_id)
Application.put_env(:ecto, :async_integration_tests, false)

Code.require_file("../deps/ecto/integration_test/support/repo.exs", __DIR__)

Code.require_file("./integration/support/schemas.exs", __DIR__)
Code.require_file("./integration/support/migration.exs", __DIR__)

alias Ecto.Integration.TestRepo

Application.put_env(
  :ecto,
  TestRepo,
  adapter: ArangoDB.Ecto,
  database: "test"
)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def init(_type, opts) do
    opts =
      opts
      |> Keyword.put(:host, System.get_env("ARANGO_SRV") || opts[:host] || "localhost")
      |> Keyword.put(:username, System.get_env("ARANGO_USR") || opts[:username])
      |> Keyword.put(:password, System.get_env("ARANGO_PWD") || opts[:password])

    {:ok, opts}
  end
end

alias Ecto.Integration.PoolRepo

Application.put_env(
  :ecto,
  PoolRepo,
  adapter: ArangoDB.Ecto,
  database_name: "pool"
)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def init(_type, opts) do
    opts =
      opts
      |> Keyword.put(:host, System.get_env("ARANGO_SRV") || opts[:host] || "localhost")
      |> Keyword.put(:username, System.get_env("ARANGO_USR") || opts[:username])
      |> Keyword.put(:password, System.get_env("ARANGO_PWD") || opts[:password])

    {:ok, opts}
  end
end

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    clear_collection(:posts)
    clear_collection(:users)
    clear_collection(:comments)
    clear_collection(:customs)
    clear_collection(:orders)
    clear_collection(:tags)
    clear_collection(:docs)
    :ok
  end

  defp clear_collection(coll) do
    :ok = ArangoDB.Ecto.truncate(TestRepo, coll)
  end
end

# Load up the repository, start it, and run migrations
_ = ArangoDB.Ecto.storage_down(TestRepo.config())
:ok = ArangoDB.Ecto.storage_up(TestRepo.config())
{:ok, _pid} = TestRepo.start_link()
:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)

_ = ArangoDB.Ecto.storage_down(PoolRepo.config())
:ok = ArangoDB.Ecto.storage_up(PoolRepo.config())
{:ok, _pid} = PoolRepo.start_link()
:ok = Ecto.Migrator.up(PoolRepo, 0, Ecto.Integration.Migration, log: false)

Process.flag(:trap_exit, true)

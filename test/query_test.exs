defmodule ArangoDB.Ecto.Query.Test do
  use ExUnit.Case
  doctest ArangoDB.Ecto

  import Ecto.Query

  defp aql(query, operation \\ :all, counter \\ 0) do
    {query, _params, _key} = Ecto.Query.Planner.prepare(query, operation, ArangoDB.Ecto, counter)
    query = Ecto.Query.Planner.normalize(query, operation, ArangoDB.Ecto, counter)
    apply(ArangoDB.Ecto.Query, operation, [query])
  end

  describe "create AQL query" do

    test "with select clause" do
      assert aql(from u in "users") =~ "FOR u0 IN `users` RETURN u0"

      assert aql(from u in "users", select: u.name) =~
        "FOR u0 IN `users` RETURN { `name`: u0.`name` }"

      assert aql(from u in "users", select: [u.name, u.age]) =~
        "FOR u0 IN `users` RETURN { `name`: u0.`name`, `age`: u0.`age` }"
    end

    test "with select distinct" do
      assert aql(from u in "users", select: u.name, distinct: true) =~
        "FOR u0 IN `users` RETURN DISTINCT { `name`: u0.`name` }"
    end

    test "with where clause" do
      assert aql(from u in "users", where: u.name == "Joe") =~
        "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') RETURN u0"

      assert aql(from u in "users", where: not(u.name == "Joe")) =~
        "FOR u0 IN `users` FILTER (NOT (u0.`name` == 'Joe')) RETURN u0"

      assert aql(from u in "users", where: like(u.name, "J%")) =~
        "FOR u0 IN `users` FILTER (u0.`name` LIKE 'J%') RETURN u0"

      name = "Joe"
      assert aql(from u in "users", where: u.name == ^name) =~
        "FOR u0 IN `users` FILTER (u0.`name` == @1) RETURN u0"

      assert aql(from u in "users", where: u.name == "Joe" and u.age == 32) =~
        "FOR u0 IN `users` FILTER ((u0.`name` == 'Joe') && (u0.`age` == 32)) RETURN u0"

      assert aql(from u in "users", where: u.name == "Joe" or u.age == 32) =~
        "FOR u0 IN `users` FILTER ((u0.`name` == 'Joe') || (u0.`age` == 32)) RETURN u0"
    end

    test "with 'in' operator in where clause" do
      assert aql(from p in "posts", where: p.title in []) =~
        "FOR p0 IN `posts` FILTER (FALSE) RETURN p0"
      assert aql(from p in "posts", where: p.title in ["1", "2", "3"]) =~
        "FOR p0 IN `posts` FILTER (p0.`title` IN ['1','2','3']) RETURN p0"
      assert aql(from p in "posts", where: not p.title in []) =~
        "FOR p0 IN `posts` FILTER (NOT (FALSE)) RETURN p0"
    end

    test "with 'in' operator and pinning in where clause" do
      assert aql(from p in "posts", where: p.title in ^[]) =~
        "FOR p0 IN `posts` FILTER (FALSE) RETURN p0"
      assert aql(from p in "posts", where: p.title in ["1", ^"hello", "3"]) =~
        "FOR p0 IN `posts` FILTER (p0.`title` IN ['1',@1,'3']) RETURN p0"
      assert aql(from p in "posts", where: p.title in ^["1", "hello", "3"]) =~
        "FOR p0 IN `posts` FILTER (p0.`title` IN [@1,@2,@3]) RETURN p0"
    end

    test "with order by clause" do
      assert aql(from u in "users", order_by: u.name) =~
        "FOR u0 IN `users` SORT u0.`name` RETURN u0"

      assert aql(from u in "users", order_by: [desc: u.name]) =~
        "FOR u0 IN `users` SORT u0.`name` DESC RETURN u0"

      assert aql(from u in "users", order_by: [desc: u.name, asc: u.age]) =~
        "FOR u0 IN `users` SORT u0.`name` DESC, u0.`age` RETURN u0"
    end

    test "with limit and offset clauses" do
      assert aql(from u in "users", limit: 10) =~
        "FOR u0 IN `users` LIMIT 10 RETURN u0"

      assert aql(from u in "users", limit: 10, offset: 2) =~
        "FOR u0 IN `users` LIMIT 2, 10 RETURN u0"

      assert_raise Ecto.QueryError, ~r"offset can only be used in conjunction with limit", fn ->
        aql(from u in "users", offset: 2)
      end
    end
  end
end

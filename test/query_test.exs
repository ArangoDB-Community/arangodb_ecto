defmodule ArangoDB.Ecto.Query.Test do
  use ExUnit.Case
  doctest ArangoDB.Ecto

  alias Ecto.Integration.{User, Post, Comment}

  import Ecto.Query

  defp aql(query, operation \\ :all, counter \\ 0) do
    {query, _params, _key} = Ecto.Query.Planner.prepare(query, operation, ArangoDB.Ecto, counter)

    {query, _} =
      query
      |> Ecto.Query.Planner.returning(true)
      |> Ecto.Query.Planner.normalize(operation, ArangoDB.Ecto, counter)

    apply(ArangoDB.Ecto.Query, operation, [query])
  end

  describe "create AQL query" do
    test "with select clause" do
      assert aql(from(u in User)) =~
               "FOR u0 IN `users` RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"

      assert aql(from(u in User, select: u.name)) =~ "FOR u0 IN `users` RETURN [ u0.`name` ]"

      assert aql(from(u in User, select: [u.name, u.age])) =~
               "FOR u0 IN `users` RETURN [ u0.`name`, u0.`age` ]"
    end

    test "with select distinct" do
      assert aql(from(u in User, select: u.name, distinct: true)) =~
               "FOR u0 IN `users` RETURN DISTINCT [ u0.`name` ]"
    end

    test "with where clause" do
      assert aql(from(u in User, where: u.name == "Joe", select: u.name)) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') RETURN [ u0.`name` ]"

      assert aql(from(u in User, where: not (u.name == "Joe"), select: u.name)) =~
               "FOR u0 IN `users` FILTER (NOT (u0.`name` == 'Joe')) RETURN [ u0.`name` ]"

      assert aql(from(u in User, where: like(u.name, "J%"), select: u.name)) =~
               "FOR u0 IN `users` FILTER (u0.`name` LIKE 'J%') RETURN [ u0.`name` ]"

      name = "Joe"

      assert aql(from(u in User, where: u.name == ^name)) =~
               "FOR u0 IN `users` FILTER (u0.`name` == @1) RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"

      assert aql(from(u in User, where: u.name == "Joe" and u.age == 32)) =~
               "FOR u0 IN `users` FILTER ((u0.`name` == 'Joe') && (u0.`age` == 32)) RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"

      assert aql(from(u in User, where: u.name == "Joe" or u.age == 32)) =~
               "FOR u0 IN `users` FILTER ((u0.`name` == 'Joe') || (u0.`age` == 32)) RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"
    end

    test "with fragments in where clause" do
      assert aql(from(o in "orders", select: o._key, where: fragment("?.price", o.item) > 10)) =~
               "FOR o0 IN `orders` FILTER (o0.`item`.price > 10) RETURN [ o0.`_key` ]"
    end

    test "with 'in' operator in where clause" do
      assert aql(from(p in "posts", where: p.title in [], select: p.title)) =~
               "FOR p0 IN `posts` FILTER (FALSE) RETURN [ p0.`title` ]"

      assert aql(from(p in "posts", where: p.title in ["1", "2", "3"], select: p.title)) =~
               "FOR p0 IN `posts` FILTER (p0.`title` IN ['1','2','3']) RETURN [ p0.`title` ]"

      assert aql(from(p in "posts", where: not (p.title in []), select: p.title)) =~
               "FOR p0 IN `posts` FILTER (NOT (FALSE)) RETURN [ p0.`title` ]"
    end

    test "with 'in' operator and pinning in where clause" do
      assert aql(from(p in "posts", where: p.title in ^[], select: p.title)) =~
               "FOR p0 IN `posts` FILTER (p0.`title` IN @1) RETURN [ p0.`title` ]"

      assert aql(from(p in "posts", where: p.title in ["1", ^"hello", "3"], select: p.title)) =~
               "FOR p0 IN `posts` FILTER (p0.`title` IN ['1',@1,'3']) RETURN [ p0.`title` ]"

      assert aql(from(p in "posts", where: p.title in ^["1", "hello", "3"], select: p.title)) =~
               "FOR p0 IN `posts` FILTER (p0.`title` IN @1) RETURN [ p0.`title` ]"

      assert aql(
               from(
                 p in "posts",
                 where: p.title in ^["1", "hello", "3"] and p.text != ^"",
                 select: p.title
               )
             ) =~
               "FOR p0 IN `posts` FILTER (p0.`title` IN @1 && (p0.`text` != @2)) RETURN [ p0.`title` ]"
    end

    test "with order by clause" do
      assert aql(from(u in User, order_by: u.name, select: u.name)) =~
               "FOR u0 IN `users` SORT u0.`name` RETURN [ u0.`name` ]"

      assert aql(from(u in User, order_by: [desc: u.name], select: u.name)) =~
               "FOR u0 IN `users` SORT u0.`name` DESC RETURN [ u0.`name` ]"

      assert aql(from(u in User, order_by: [desc: u.name, asc: u.age], select: u.name)) =~
               "FOR u0 IN `users` SORT u0.`name` DESC, u0.`age` RETURN [ u0.`name` ]"
    end

    test "with limit and offset clauses" do
      assert aql(from(u in User, limit: 10)) =~
               "FOR u0 IN `users` LIMIT 10 RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"

      assert aql(from(u in User, limit: 10, offset: 2)) =~
               "FOR u0 IN `users` LIMIT 2, 10 RETURN [ u0.`_key`, u0.`name`, u0.`age`, u0.`hobbies`, u0.`inserted_at`, u0.`updated_at` ]"

      assert_raise Ecto.QueryError, ~r"offset can only be used in conjunction with limit", fn ->
        aql(from(u in User, offset: 2))
      end
    end

    test "with join" do
      assert aql(
               from(
                 c in Comment,
                 join: p in Post,
                 on: p._key == c.post__key,
                 select: {p.title, c.text}
               )
             ) =~
               "FOR c0 IN `comments` FOR p1 IN `posts` FILTER p1.`_key` == c0.`post__key` RETURN [ p1.`title`, c0.`text` ]"
    end

    test "with is_nil in where clause" do
      assert aql(from(u in User, select: u._key, where: is_nil(u.name))) =~
               "FOR u0 IN `users` FILTER (u0.`name` == NULL) RETURN [ u0.`_key` ]"
    end

    test "with datetime_add in where clause" do
      num_days = 5
      assert aql(from(u in User, select: u._key, where: datetime_add(u.inserted_at, ^num_days, "day") < ^DateTime.utc_now())) =~
               "FOR u0 IN `users` FILTER (DATE_ADD(u0.`inserted_at`, @1, \"day\") < @2) RETURN [ u0.`_key` ]"
    end

    test "with date_add in where clause" do
      assert aql(from(p in Post, select: p._key, where: date_add(p.posted, p.counter, "day") < ^Date.utc_today())) =~
               "FOR p0 IN `posts` FILTER (LEFT(DATE_ADD(p0.`posted`, p0.`counter`, \"day\"), 10) < @1) RETURN [ p0.`_key` ]"
    end
  end

  describe "create remove query" do
    test "without returning" do
      assert aql(from(u in User, where: u.name == "Joe"), :delete_all) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') REMOVE u0 IN `users`"
    end

    test "with returning" do
      assert aql(from(u in User, where: u.name == "Joe", select: u), :delete_all) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') REMOVE u0 IN `users` RETURN [ OLD.`_key`, OLD.`name`, OLD.`age`, OLD.`hobbies`, OLD.`inserted_at`, OLD.`updated_at` ]"

      assert aql(from(u in User, where: u.name == "Joe", select: u.name), :delete_all) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') REMOVE u0 IN `users` RETURN [ OLD.`name` ]"
    end
  end

  describe "create update query" do
    test "without returning" do
      assert aql(from(u in User, where: u.name == "Joe", update: [set: [age: 42]]), :update_all) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') UPDATE u0 WITH {`age`: 42} IN `users`"

      assert aql(from(u in User, where: u.name == "Joe", update: [inc: [age: 2]]), :update_all) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') UPDATE u0 WITH {`age`: u0.`age` + 2} IN `users`"
    end

    test "with returning" do
      assert aql(
               from(u in User, where: u.name == "Joe", select: u, update: [set: [age: 42]]),
               :update_all
             ) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') UPDATE u0 WITH {`age`: 42} IN `users` RETURN [ NEW.`_key`, NEW.`name`, NEW.`age`, NEW.`hobbies`, NEW.`inserted_at`, NEW.`updated_at` ]"

      assert aql(
               from(u in User, where: u.name == "Joe", select: u.name, update: [set: [age: 42]]),
               :update_all
             ) =~
               "FOR u0 IN `users` FILTER (u0.`name` == 'Joe') UPDATE u0 WITH {`age`: 42} IN `users` RETURN [ NEW.`name` ]"
    end
  end
end

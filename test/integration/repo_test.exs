defmodule Ecto.Integration.RepoTest do
  use Ecto.Integration.Case, async: false

  import Ecto.Query

  alias Ecto.Integration.{TestRepo, Post, User, Comment, Custom}

  test "returns already started for started repos" do
    assert {:error, {:already_started, _}} = TestRepo.start_link
  end

  test "fetch empty" do
    assert [] == TestRepo.all(Post)
    assert [] == TestRepo.all(from p in Post)
  end

  test "query" do
    TestRepo.insert!(%Post{title: "hello"})
    assert {:ok, [%{"title" => "hello"}]} = ArangoDB.Ecto.query(TestRepo, "FOR p in posts RETURN p")
  end

  test "fetch with in" do
    TestRepo.insert!(%Post{title: "hello"})

    assert []  = TestRepo.all from p in Post, where: p.title in []
    assert []  = TestRepo.all from p in Post, where: p.title in ["1", "2", "3"]
    assert []  = TestRepo.all from p in Post, where: p.title in ^[]

    assert [_] = TestRepo.all from p in Post, where: not p.title in []
    assert [_] = TestRepo.all from p in Post, where: p.title in ["1", "hello", "3"]
    assert [_] = TestRepo.all from p in Post, where: p.title in ["1", ^"hello", "3"]
    assert [_] = TestRepo.all from p in Post, where: p.title in ^["1", "hello", "3"]
  end

  test "fetch without schema" do
    %Post{} = TestRepo.insert!(%Post{title: "title1"})
    %Post{} = TestRepo.insert!(%Post{title: "title2"})

    assert ["title1", "title2"] =
      TestRepo.all(from(p in "posts", order_by: p.title, select: p.title))

    assert [_] =
      TestRepo.all(from(p in "posts", where: p.title == "title1", select: p._key))
  end

  @tag :invalid_prefix
  test "fetch with invalid prefix" do
    assert catch_error(TestRepo.all("posts", prefix: "oops"))
  end

  test "insert, update and delete" do
    post = %Post{title: "insert, update, delete", text: "fetch empty"}
    meta = post.__meta__

    deleted_meta = put_in meta.state, :deleted
    assert %Post{} = to_be_deleted = TestRepo.insert!(post)
    assert %Post{__meta__: ^deleted_meta} = TestRepo.delete!(to_be_deleted)

    loaded_meta = put_in meta.state, :loaded
    assert %Post{__meta__: ^loaded_meta} = TestRepo.insert!(post)

    post = TestRepo.one(Post)
    assert post.__meta__.state == :loaded
    assert post.inserted_at
  end

  @tag :invalid_prefix
  test "insert, update and delete with invalid prefix" do
    post = TestRepo.insert!(%Post{})
    changeset = Ecto.Changeset.change(post, title: "foo")
    assert catch_error(TestRepo.insert(%Post{}, prefix: "oops"))
    assert catch_error(TestRepo.update(changeset, prefix: "oops"))
    assert catch_error(TestRepo.delete(changeset, prefix: "oops"))
  end

  test "insert and update with changeset" do
    # On insert we merge the fields and changes
    changeset = Ecto.Changeset.cast(%Post{text: "x", title: "wrong"},
                                    %{"title" => "hello", "temp" => "unknown"}, ~w(title temp))

    post = TestRepo.insert!(changeset)
    assert %Post{text: "x", title: "hello", temp: "unknown"} = post
    assert %Post{text: "x", title: "hello", temp: "temp"} = TestRepo.get!(Post, post._key)

    # On update we merge only fields, direct schema changes are discarded
    changeset = Ecto.Changeset.cast(%{post | text: "y"},
                                    %{"title" => "world", "temp" => "unknown"}, ~w(title temp))

    assert %Post{text: "y", title: "world", temp: "unknown"} = TestRepo.update!(changeset)
    assert %Post{text: "x", title: "world", temp: "temp"} = TestRepo.get!(Post, post._key)
  end

  test "insert and update with empty changeset" do
    # On insert we merge the fields and changes
    changeset = Ecto.Changeset.cast(%Post{}, %{}, ~w())
    assert %Post{} = post = TestRepo.insert!(changeset)

    # Assert we can update the same value twice,
    # without changes, without triggering stale errors.
    changeset = Ecto.Changeset.cast(post, %{}, ~w())
    assert TestRepo.update!(changeset) == post
    assert TestRepo.update!(changeset) == post
  end

  @tag :read_after_writes
  test "insert and update with changeset read after writes" do
    defmodule RAW do
      use ArangoDB.Ecto.Schema

      schema "comments" do
        field :text, :string
        field :_rev, :binary, read_after_writes: true
      end
    end

    changeset = Ecto.Changeset.cast(struct(RAW, %{}), %{}, ~w())
    assert %{_key: cid, _rev: rev1} = raw = TestRepo.insert!(changeset)

    changeset = Ecto.Changeset.cast(raw, %{"text" => "0"}, ~w(text))
    assert %{_key: ^cid, _rev: rev2, text: "0"} = TestRepo.update!(changeset)
    assert rev1 != rev2
  end

  @tag :id_type
  @tag :assigns_id_type
  test "insert with user-assigned primary key" do
    assert %Post{_key: "1"} = TestRepo.insert!(%Post{_key: "1"})
  end

  @tag :id_type
  @tag :assigns_id_type
  test "insert and update with user-assigned primary key in changeset" do
    changeset = Ecto.Changeset.cast(%Post{_key: "11"}, %{"_key" => "13"}, ~w(_key))
    assert %Post{_key: "13"} = post = TestRepo.insert!(changeset)

    changeset = Ecto.Changeset.cast(post, %{"_key" => "15"}, ~w(_key))
    assert %Post{_key: "15"} = TestRepo.update!(changeset)
  end

  test "insert and fetch a schema with utc timestamps" do
    datetime = System.system_time(:seconds) * 1_000_000 |> DateTime.from_unix!(:microseconds)
    TestRepo.insert!(%User{inserted_at: datetime})
    assert [%{inserted_at: ^datetime}] = TestRepo.all(User)
  end

  # TODO
#  test "optimistic locking in update/delete operations" do
#    import Ecto.Changeset, only: [cast: 3, optimistic_lock: 2]
#    base_post = TestRepo.insert!(%Comment{})
#
#    cs_ok =
#      base_post
#      |> cast(%{"text" => "foo.bar"}, ~w(text))
#      |> optimistic_lock(:_rev)
#    TestRepo.update!(cs_ok)
#
#    cs_stale = optimistic_lock(base_post, :_rev)
#    assert_raise Ecto.StaleEntryError, fn -> TestRepo.update!(cs_stale) end
#    a#ssert_raise Ecto.StaleEntryError, fn -> TestRepo.delete!(cs_stale) end
#  end

  @tag :unique_constraint
  test "unique constraint" do
    changeset = Ecto.Changeset.change(%Custom{}, uuid: Ecto.UUID.generate())
    {:ok, _}  = TestRepo.insert(changeset)

    exception =
      assert_raise Ecto.ConstraintError, ~r/constraint error when attempting to insert struct/, fn ->
        changeset
        |> TestRepo.insert()
      end

    assert exception.message =~ "unique: constraint violated"
    assert exception.message =~ "The changeset has not defined any constraint."

    message = ~r/constraint error when attempting to insert struct/
    exception =
      assert_raise Ecto.ConstraintError, message, fn ->
        changeset
        |> Ecto.Changeset.unique_constraint(:uuid, name: :my_unique_constraint)
        |> TestRepo.insert()
      end

    assert exception.message =~ "unique: my_unique_constraint"
  end

  test "get(!)" do
    post1 = TestRepo.insert!(%Post{title: "1", text: "hai"})
    post2 = TestRepo.insert!(%Post{title: "2", text: "hai"})

    assert post1 == TestRepo.get(Post, post1._key)
    assert post2 == TestRepo.get(Post, to_string post2._key) # With casting

    assert post1 == TestRepo.get!(Post, post1._key)
    assert post2 == TestRepo.get!(Post, to_string post2._key) # With casting

    TestRepo.delete!(post1)

    assert nil   == TestRepo.get(Post, post1._key)
    assert_raise Ecto.NoResultsError, fn ->
      TestRepo.get!(Post, post1._key)
    end
  end

  test "get(!) with custom source" do
    custom = Ecto.put_meta(%Custom{}, source: "posts")
    custom = TestRepo.insert!(custom)
    key    = custom._key
    id = "posts/#{key}"
    assert %Custom{_id: ^id, _key: ^key, __meta__: %{source: {nil, "posts"}}} =
           TestRepo.get(from(c in {"posts", Custom}), key)
  end

  test "get(!) with binary_id" do
    custom = TestRepo.insert!(%Custom{})
    key = custom._key
    assert %Custom{_key: ^key} = TestRepo.get(Custom, key)
  end

  test "get_by(!)" do
    post1 = TestRepo.insert!(%Post{title: "1", text: "hai"})
    post2 = TestRepo.insert!(%Post{title: "2", text: "hello"})

    assert post1 == TestRepo.get_by(Post, _key: post1._key)
    assert post1 == TestRepo.get_by(Post, text: post1.text)
    assert post1 == TestRepo.get_by(Post, _key: post1._key, text: post1.text)
    assert post2 == TestRepo.get_by(Post, _key: to_string(post2._key)) # With casting
    assert nil   == TestRepo.get_by(Post, text: "hey")
    assert nil   == TestRepo.get_by(Post, _key: post2._key, text: "hey")

    assert post1 == TestRepo.get_by!(Post, _key: post1._key)
    assert post1 == TestRepo.get_by!(Post, text: post1.text)
    assert post1 == TestRepo.get_by!(Post, _key: post1._key, text: post1.text)
    assert post2 == TestRepo.get_by!(Post, _key: to_string(post2._key)) # With casting

    assert post1 == TestRepo.get_by!(Post, %{_key: post1._key})

    assert_raise Ecto.NoResultsError, fn ->
      TestRepo.get_by!(Post, _key: post2._key, text: "hey")
    end
  end

  test "first, last and one(!)" do
    post1 = TestRepo.insert!(%Post{title: "1", text: "hai"})
    post2 = TestRepo.insert!(%Post{title: "2", text: "hai"})

    assert post1 == Post |> first |> TestRepo.one
    assert post2 == Post |> last |> TestRepo.one

    query = from p in Post, order_by: p.title
    assert post1 == query |> first |> TestRepo.one
    assert post2 == query |> last |> TestRepo.one

    query = from p in Post, order_by: [desc: p.title], limit: 10
    assert post2 == query |> first |> TestRepo.one
    assert post1 == query |> last |> TestRepo.one

    query = from p in Post, where: is_nil(p._key)
    refute query |> first |> TestRepo.one
    refute query |> first |> TestRepo.one
    assert_raise Ecto.NoResultsError, fn -> query |> first |> TestRepo.one! end
    assert_raise Ecto.NoResultsError, fn -> query |> last |> TestRepo.one! end
  end

  test "insert all" do
    assert {2, nil} = TestRepo.insert_all("comments", [[text: "1"], %{text: "2"}])
    assert {2, nil} = TestRepo.insert_all({"comments", Comment}, [[text: "3"], %{text: "4"}])
    assert [%Comment{text: "1"},
            %Comment{text: "2"},
            %Comment{text: "3"},
            %Comment{text: "4"}] = TestRepo.all(Comment |> order_by(:text))

    assert {2, nil} = TestRepo.insert_all(Post, [[], []])
    assert [%Post{}, %Post{}] = TestRepo.all(Post)

    assert {0, nil} = TestRepo.insert_all("posts", [])
    assert {0, nil} = TestRepo.insert_all({"posts", Post}, [])
  end

  @tag :invalid_prefix
  test "insert all with invalid prefix" do
    assert catch_error(TestRepo.insert_all(Post, [[], []], prefix: "oops"))
  end

  @tag :returning
  test "insert all with returning with schema" do
    assert {0, []} = TestRepo.insert_all(Comment, [], returning: true)
    assert {0, nil} = TestRepo.insert_all(Comment, [], returning: false)

    {2, [c1, c2]} = TestRepo.insert_all(Comment, [[text: "1"], [text: "2"]], returning: [:_key, :text])
    assert %Comment{text: "1", __meta__: %{state: :loaded}} = c1
    assert %Comment{text: "2", __meta__: %{state: :loaded}} = c2

    {2, [c1, c2]} = TestRepo.insert_all(Comment, [[text: "3"], [text: "4"]], returning: true)
    assert %Comment{text: "3", __meta__: %{state: :loaded}} = c1
    assert %Comment{text: "4", __meta__: %{state: :loaded}} = c2
  end

  @tag :returning
  test "insert all with returning without schema" do
    {2, [c1, c2]} = TestRepo.insert_all("comments", [[text: "1"], [text: "2"]], returning: [:_key, :text])
    assert %{_key: _, text: "1"} = c1
    assert %{_key: _, text: "2"} = c2

    assert_raise ArgumentError, fn ->
      TestRepo.insert_all("comments", [[text: "1"], [text: "2"]], returning: true)
    end
  end

  test "insert all with dumping" do
    datetime = ~N[2014-01-16 20:26:51.000000]
    assert {2, nil} = TestRepo.insert_all(Post, [%{inserted_at: datetime}, %{title: "date"}])
    assert [%Post{inserted_at: ^datetime, title: nil},
            %Post{inserted_at: nil, title: "date"}] = TestRepo.all(Post |> order_by(:title))
  end

  test "insert all autogenerates for binary_id type" do
    custom = TestRepo.insert!(%Custom{_key: nil})
    assert custom._key
    assert TestRepo.get(Custom, custom._key)
    assert TestRepo.delete!(custom)
    refute TestRepo.get(Custom, custom._key)

    uuid = Ecto.UUID.generate
    assert {2, nil} = TestRepo.insert_all(Custom, [%{uuid: uuid}, %{_key: custom._key}])
    assert [%Custom{_key: key2, uuid: nil},
            %Custom{_key: key1, uuid: ^uuid}] = Enum.sort_by(TestRepo.all(Custom), & &1.uuid)
    assert key1 && key2
    assert custom._key != key1
    assert custom._key == key2
  end

  test "update all" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3"})

    assert {0, []} = TestRepo.update_all(from(p in Post, where: false), [set: [title: "x"]], returning: true)

    assert {3, nil} = TestRepo.update_all(Post, set: [title: "x"])

    assert %Post{title: "x"} = TestRepo.get(Post, id1)
    assert %Post{title: "x"} = TestRepo.get(Post, id2)
    assert %Post{title: "x"} = TestRepo.get(Post, id3)

    assert {3, nil} = TestRepo.update_all("posts", [set: [title: nil]], returning: false)

    assert %Post{title: nil} = TestRepo.get(Post, id1)
    assert %Post{title: nil} = TestRepo.get(Post, id2)
    assert %Post{title: nil} = TestRepo.get(Post, id3)
  end

  @tag :invalid_prefix
  test "update all with invalid prefix" do
    assert catch_error(TestRepo.update_all(Post, [set: [title: "x"]], prefix: "oops"))
  end

  @tag :returning
  test "update all with returning with schema" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3"})

    assert {3, posts} = TestRepo.update_all(Post, [set: [title: "x"]], returning: true)

    [p1, p2, p3] = Enum.sort_by(posts, & &1._key)
    assert %Post{_key: ^id1, title: "x"} = p1
    assert %Post{_key: ^id2, title: "x"} = p2
    assert %Post{_key: ^id3, title: "x"} = p3

    assert {3, posts} = TestRepo.update_all(Post, [set: [visits: 11]], returning: [:_key, :visits])

    [p1, p2, p3] = Enum.sort_by(posts, & &1._key)
    assert %Post{_key: ^id1, title: nil, visits: 11} = p1
    assert %Post{_key: ^id2, title: nil, visits: 11} = p2
    assert %Post{_key: ^id3, title: nil, visits: 11} = p3
  end

  @tag :returning
  test "update all with returning without schema" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3"})

    assert {3, posts} = TestRepo.update_all("posts", [set: [title: "x"]], returning: [:_key, :title])

    [p1, p2, p3] = Enum.sort_by(posts, & &1._key)
    assert p1 == %{_key: id1, title: "x"}
    assert p2 == %{_key: id2, title: "x"}
    assert p3 == %{_key: id3, title: "x"}
  end

  test "update all with filter" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3"})

    query = from(p in Post, where: p.title == "1" or p.title == "2",
                            update: [set: [text: ^"y"]])
    assert {2, nil} = TestRepo.update_all(query, set: [title: "x"])

    assert %Post{title: "x", text: "y"} = TestRepo.get(Post, id1)
    assert %Post{title: "x", text: "y"} = TestRepo.get(Post, id2)
    assert %Post{title: "3", text: nil} = TestRepo.get(Post, id3)
  end

  test "update all no entries" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3"})

    query = from(p in Post, where: p.title == "4")
    assert {0, nil} = TestRepo.update_all(query, set: [title: "x"])

    assert %Post{title: "1"} = TestRepo.get(Post, id1)
    assert %Post{title: "2"} = TestRepo.get(Post, id2)
    assert %Post{title: "3"} = TestRepo.get(Post, id3)
  end

  test "update all increment syntax" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1", visits: 0})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2", visits: 1})

    # Positive
    query = from p in Post, where: not is_nil(p._key), update: [inc: [visits: 2]]
    assert {2, nil} = TestRepo.update_all(query, [])

    assert %Post{visits: 2} = TestRepo.get(Post, id1)
    assert %Post{visits: 3} = TestRepo.get(Post, id2)

    # Negative
    query = from p in Post, where: not is_nil(p._key), update: [inc: [visits: -1]]
    assert {2, nil} = TestRepo.update_all(query, [])

    assert %Post{visits: 1} = TestRepo.get(Post, id1)
    assert %Post{visits: 2} = TestRepo.get(Post, id2)
  end

  @tag :id_type
  test "update all with casting and dumping on _key type field" do
    assert %Post{_key: key} = TestRepo.insert!(%Post{})
    counter = String.to_integer(key)
    assert {1, nil} = TestRepo.update_all(Post, set: [counter: to_string(counter)])
    assert %Post{counter: ^counter} = TestRepo.get(Post, key)
  end

  test "update all with casting and dumping" do
    text = "hai"
    datetime = ~N[2014-01-16 20:26:51.000000]
    assert %Post{_key: key} = TestRepo.insert!(%Post{})

    assert {1, nil} = TestRepo.update_all(Post, set: [text: text, inserted_at: datetime])
    assert %Post{text: "hai", inserted_at: ^datetime} = TestRepo.get(Post, key)
  end

  test "delete all" do
    assert %Post{} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert %Post{} = TestRepo.insert!(%Post{title: "2", text: "hai"})
    assert %Post{} = TestRepo.insert!(%Post{title: "3", text: "hai"})

    assert {3, nil} = TestRepo.delete_all(Post, returning: false)
    assert [] = TestRepo.all(Post)
  end

  @tag :invalid_prefix
  test "delete all with invalid prefix" do
    assert catch_error(TestRepo.delete_all(Post, prefix: "oops"))
  end

  @tag :returning
  test "delete all with returning with schema" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2", text: "hai"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3", text: "hai"})

    assert {3, posts} = TestRepo.delete_all(Post, returning: true)

    [p1, p2, p3] = Enum.sort_by(posts, & &1._key)
    assert %Post{_key: ^id1, title: "1"} = p1
    assert %Post{_key: ^id2, title: "2"} = p2
    assert %Post{_key: ^id3, title: "3"} = p3
  end

  @tag :returning
  test "delete all with returning without schema" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2", text: "hai"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3", text: "hai"})

    assert {3, posts} = TestRepo.delete_all("posts", returning: [:_key, :title])

    [p1, p2, p3] = Enum.sort_by(posts, & &1._key)
    assert p1 == %{_key: id1, title: "1"}
    assert p2 == %{_key: id2, title: "2"}
    assert p3 == %{_key: id3, title: "3"}
  end

  test "delete all with filter" do
    assert %Post{} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert %Post{} = TestRepo.insert!(%Post{title: "2", text: "hai"})
    assert %Post{} = TestRepo.insert!(%Post{title: "3", text: "hai"})

    query = from(p in Post, where: p.title == "1" or p.title == "2")
    assert {2, nil} = TestRepo.delete_all(query)
    assert [%Post{}] = TestRepo.all(Post)
  end

  test "delete all no entries" do
    assert %Post{_key: id1} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert %Post{_key: id2} = TestRepo.insert!(%Post{title: "2", text: "hai"})
    assert %Post{_key: id3} = TestRepo.insert!(%Post{title: "3", text: "hai"})

    query = from(p in Post, where: p.title == "4")
    assert {0, nil} = TestRepo.delete_all(query)
    assert %Post{title: "1"} = TestRepo.get(Post, id1)
    assert %Post{title: "2"} = TestRepo.get(Post, id2)
    assert %Post{title: "3"} = TestRepo.get(Post, id3)
  end

  test "virtual field" do
    assert %Post{_key: key} = TestRepo.insert!(%Post{title: "1", text: "hai"})
    assert TestRepo.get(Post, key).temp == "temp"
  end

  ## Query syntax

  test "query select expressions" do
    %Post{} = TestRepo.insert!(%Post{title: "1", text: "hai"})

    assert [{"1", "hai"}] ==
           TestRepo.all(from p in Post, select: {p.title, p.text})

    assert [["1", "hai"]] ==
           TestRepo.all(from p in Post, select: [p.title, p.text])

    assert [%{:title => "1", 3 => "hai", "text" => "hai"}] ==
           TestRepo.all(from p in Post, select: %{
             :title => p.title,
             "text" => p.text,
             3 => p.text
           })

    assert [%{:title => "1", "1" => "hai", "text" => "hai"}] ==
           TestRepo.all(from p in Post, select: %{
             :title  => p.title,
             p.title => p.text,
             "text"  => p.text
           })
  end

  test "query select map update" do
    %Post{} = TestRepo.insert!(%Post{title: "1", text: "hai"})

    assert [%Post{:title => "new title", text: "hai"}] =
           TestRepo.all(from p in Post, select: %{p | title: "new title"})

    assert_raise KeyError, fn ->
      TestRepo.all(from p in Post, select: %{p | unknown: "new title"})
    end

    assert_raise BadMapError, fn ->
      TestRepo.all(from p in Post, select: %{p.title | title: "new title"})
    end
  end

  test "query select take with structs" do
    %{_key: pid1} = TestRepo.insert!(%Post{title: "1"})
    %{_key: pid2} = TestRepo.insert!(%Post{title: "2"})
    %{_key: pid3} = TestRepo.insert!(%Post{title: "3"})

    [p1, p2, p3] = Post |> select([p], struct(p, [:title])) |> order_by([:title]) |> TestRepo.all
    refute p1._key
    assert p1.title == "1"
    assert match?(%Post{}, p1)
    refute p2._key
    assert p2.title == "2"
    assert match?(%Post{}, p2)
    refute p3._key
    assert p3.title == "3"
    assert match?(%Post{}, p3)

    [p1, p2, p3] = Post |> select([:_key]) |> order_by([:_key]) |> TestRepo.all
    assert %Post{_key: ^pid1} = p1
    assert %Post{_key: ^pid2} = p2
    assert %Post{_key: ^pid3} = p3
  end

  test "query select take with maps" do
    %{_key: pid1} = TestRepo.insert!(%Post{title: "1"})
    %{_key: pid2} = TestRepo.insert!(%Post{title: "2"})
    %{_key: pid3} = TestRepo.insert!(%Post{title: "3"})

    [p1, p2, p3] = "posts" |> select([p], map(p, [:title])) |> order_by([:title]) |> TestRepo.all
    assert p1 == %{title: "1"}
    assert p2 == %{title: "2"}
    assert p3 == %{title: "3"}

    [p1, p2, p3] = "posts" |> select([:_key]) |> order_by([:_key]) |> TestRepo.all
    assert p1 == %{_key: pid1}
    assert p2 == %{_key: pid2}
    assert p3 == %{_key: pid3}
  end

  test "query select take with assocs" do
    %{_key: pid} = TestRepo.insert!(%Post{title: "post"})
    TestRepo.insert!(%Comment{post__key: pid, text: "comment"})
    fields = [:_key, :title, comments: [:text, :post__key]]

    [p] = Post |> preload(:comments) |> select([p], ^fields) |> TestRepo.all
    assert %Post{title: "post"} = p
    assert [%Comment{text: "comment"}] = p.comments

    [p] = Post |> preload(:comments) |> select([p], struct(p, ^fields)) |> TestRepo.all
    assert %Post{title: "post"} = p
    assert [%Comment{text: "comment"}] = p.comments

    [p] = Post |> preload(:comments) |> select([p], map(p, ^fields)) |> TestRepo.all
    assert p == %{_key: pid, title: "post", comments: [%{text: "comment", post__key: pid}]}
  end

  test "query select take with single nil column" do
    %Post{} = TestRepo.insert!(%Post{title: "1", counter: nil})
    assert %{counter: nil} =
           TestRepo.one(from p in Post, where: p.title == "1", select: [:counter])
  end

  test "query select take with nil assoc" do
    %{_key: cid} = TestRepo.insert!(%Comment{text: "comment"})
    fields = [:_key, :text, post: [:title]]

    [c] = Comment |> preload(:post) |> select([c], ^fields) |> TestRepo.all
    assert %Comment{_key: ^cid, text: "comment", post: nil} = c

    [c] = Comment |> preload(:post) |> select([c], struct(c, ^fields)) |> TestRepo.all
    assert %Comment{_key: ^cid, text: "comment", post: nil} = c

    [c] = Comment |> preload(:post) |> select([c], map(c, ^fields)) |> TestRepo.all
    assert c == %{_key: cid, text: "comment", post: nil}
  end

  test "query where interpolation" do
    post1 = TestRepo.insert!(%Post{text: "x", title: "hello"})
    post2 = TestRepo.insert!(%Post{text: "y", title: "goodbye"})

    assert [post1, post2] == Post |> where([], []) |> TestRepo.all |> Enum.sort_by(& &1._key)
    assert [post1]        == Post |> where([], [title: "hello"]) |> TestRepo.all
    assert [post1]        == Post |> where([], [title: "hello", _key: ^post1._key]) |> TestRepo.all

    params0 = []
    params1 = [title: "hello"]
    params2 = [title: "hello", _key: post1._key]
    assert [post1, post2]  == (from Post, where: ^params0) |> TestRepo.all |> Enum.sort_by(& &1._key)
    assert [post1]         == (from Post, where: ^params1) |> TestRepo.all
    assert [post1]         == (from Post, where: ^params2) |> TestRepo.all

    post3 = TestRepo.insert!(%Post{text: "y", title: "goodbye", uuid: nil})
    params3 = [title: "goodbye", uuid: post3.uuid]
    assert [post3] == (from Post, where: ^params3) |> TestRepo.all
  end

  test "many_to_many changeset assoc with self-referential binary_id" do
    assoc_custom = TestRepo.insert!(%Custom{uuid: "1"})
    custom = TestRepo.insert!(%Custom{customs: [assoc_custom], uuid: "2"})

    custom = Custom |> TestRepo.get!(custom._key) |> TestRepo.preload(:customs)
    assert [_] = custom.customs

    custom =
      custom
      |> Ecto.Changeset.change(%{})
      |> Ecto.Changeset.put_assoc(:customs, [])
      |> TestRepo.update!
    assert [] = custom.customs

    custom = Custom |> TestRepo.get!(custom._key) |> TestRepo.preload(:customs)
    assert [] = custom.customs
  end
end
defmodule ArangoDB.Ecto.Integration.TypesTest do
  use Ecto.Integration.Case, async: false

  import Ecto.Query

  alias Ecto.Integration.{TestRepo, Post, User, Tag, Item, Order}

  test "primitive types" do
    integer  = 1
    float    = 0.1
    title    = "types test"
    uuid     = "00010203-0405-0607-0809-0a0b0c0d0e0f"
    boolean  = true
    datetime = ~N[2014-01-16 20:26:51.000]
    mdate    = ~D[2017-12-04]
    mtime    = ~T[15:20:48]

    TestRepo.insert!(%Post{title: title, public: boolean, visits: integer, uuid: uuid,
                           counter: integer, inserted_at: datetime, intensity: float,
                           modification_date: mdate, modification_time: mtime})

    # nil
    assert [nil] = TestRepo.all(from p in Post, select: p.ip)

    # ID
    assert [1] = TestRepo.all(from p in Post, where: p.counter == ^integer, select: p.counter)

    # Integers
    assert [1] = TestRepo.all(from p in Post, where: p.visits == ^integer, select: p.visits)
    assert [1] = TestRepo.all(from p in Post, where: p.visits == 1, select: p.visits)

    # Floats
    assert [0.1] = TestRepo.all(from p in Post, where: p.intensity == ^float, select: p.intensity)
    assert [0.1] = TestRepo.all(from p in Post, where: p.intensity == 0.1, select: p.intensity)

    # Booleans
    assert [true] = TestRepo.all(from p in Post, where: p.public == ^boolean, select: p.public)
    assert [true] = TestRepo.all(from p in Post, where: p.public == true, select: p.public)

    # UUID
    assert [^uuid] = TestRepo.all(from p in Post, where: p.uuid == ^uuid, select: p.uuid)

    # NaiveDatetime
    assert [^datetime] = TestRepo.all(from p in Post, where: p.inserted_at == ^datetime, select: p.inserted_at)

    #Date
    assert [^mdate] = TestRepo.all(from p in Post, where: p.modification_date == ^mdate, select: p.modification_date)

    #Time
    assert [^mtime] = TestRepo.all(from p in Post, where: p.modification_time == ^mtime, select: p.modification_time)
    
    # Datetime
    datetime = DateTime.utc_now |> Map.update(:microsecond, {0, 0}, fn {x, _} -> {div(x, 1000) * 1000, 3} end)
    TestRepo.insert!(%User{inserted_at: datetime})
    assert [^datetime] = TestRepo.all(from u in User, where: u.inserted_at == ^datetime, select: u.inserted_at)
  end

  test "float type conversion for values that can be encoded as integer" do
    TestRepo.insert!(%Post{intensity: 10.0})

    assert [10.0] = TestRepo.all(from p in Post, select: p.intensity)
  end

  test "uuid types" do
    assert %Post{} = post = TestRepo.insert!(%Post{title: "bid test", uuid: Ecto.UUID.generate(), timeuuid: Ecto.UUID.generate()})
    uuid = post.uuid
    timeuuid = post.timeuuid
    assert [[^uuid, ^timeuuid]] = TestRepo.all(from p in Post, select: [p.uuid, p.timeuuid])
  end

  @tag :array_type
  test "array type" do
    ints = [1, 2, 3]
    tag = TestRepo.insert!(%Tag{ints: ints})

    assert TestRepo.all(from t in Tag, where: t.ints == ^[], select: t.ints) == []
    assert TestRepo.all(from t in Tag, where: t.ints == ^[1, 2, 3], select: t.ints) == [ints]

    # Both sides interpolation
    assert TestRepo.all(from t in Tag, where: ^"b" in ^["a", "b", "c"], select: t.ints) == [ints]
    assert TestRepo.all(from t in Tag, where: ^"b" in [^"a", ^"b", ^"c"], select: t.ints) == [ints]

    # Querying
    assert TestRepo.all(from t in Tag, where: t.ints == [1, 2, 3], select: t.ints) == [ints]
    assert TestRepo.all(from t in Tag, where: 0 in t.ints, select: t.ints) == []
    assert TestRepo.all(from t in Tag, where: 1 in t.ints, select: t.ints) == [ints]

    # Update
    tag = TestRepo.update!(Ecto.Changeset.change tag, ints: [3, 2, 1])
    assert TestRepo.get!(Tag, tag._key).ints == [3, 2, 1]

    # Update all
    {1, _} = TestRepo.update_all(Tag, push: [ints: 0])
    assert TestRepo.get!(Tag, tag._key).ints == [3, 2, 1, 0]

    {1, _} = TestRepo.update_all(Tag, pull: [ints: 2])
    assert TestRepo.get!(Tag, tag._key).ints == [3, 1, 0]
  end

  @tag :array_type
  test "array type with custom types" do
    uuids = ["51fcfbdd-ad60-4ccb-8bf9-47aabd66d075"]
    TestRepo.insert!(%Tag{uuids: ["51fcfbdd-ad60-4ccb-8bf9-47aabd66d075"]})

    assert TestRepo.all(from t in Tag, where: t.uuids == ^[], select: t.uuids) == []
    assert TestRepo.all(from t in Tag, where: t.uuids == ^["51fcfbdd-ad60-4ccb-8bf9-47aabd66d075"],
                                       select: t.uuids) == [uuids]
  end

  @tag :array_type
  test "array type with nil in array" do
    tag = TestRepo.insert!(%Tag{ints: [1, nil, 3]})
    assert tag.ints == [1, nil, 3]
  end

  @tag :map_type
  test "untyped map" do
    post1 = TestRepo.insert!(%Post{meta: %{"foo" => "bar", "baz" => "bat"}})
    post2 = TestRepo.insert!(%Post{meta: %{foo: "bar", baz: "bat"}})

    assert TestRepo.all(from p in Post, where: p._key == ^post1._key, select: p.meta) ==
           [%{"foo" => "bar", "baz" => "bat"}]
    assert TestRepo.all(from p in Post, where: p._key == ^post2._key, select: p.meta) ==
           [%{"foo" => "bar", "baz" => "bat"}]
  end

  @tag :map_type
  test "typed map" do
    post1 = TestRepo.insert!(%Post{links: %{"foo" => "http://foo.com", "bar" => "http://bar.com"}})
    post2 = TestRepo.insert!(%Post{links: %{foo: "http://foo.com", bar: "http://bar.com"}})

    assert TestRepo.all(from p in Post, where: p._key == ^post1._key, select: p.links) ==
           [%{"foo" => "http://foo.com", "bar" => "http://bar.com"}]
    assert TestRepo.all(from p in Post, where: p._key == ^post2._key, select: p.links) ==
           [%{"foo" => "http://foo.com", "bar" => "http://bar.com"}]
  end

  @tag :map_type
  test "map type on update" do
    post = TestRepo.insert!(%Post{meta: %{"world" => "hello"}})
    assert TestRepo.get!(Post, post._key).meta == %{"world" => "hello"}

    # TODO - by default ArangoDB merges objects
    #post = TestRepo.update!(Ecto.Changeset.change(post, meta: %{hello: "world"}))
    #assert TestRepo.get!(Post, post._key).meta == %{"hello" => "world"}

    query = from(p in Post, where: p._key == ^post._key)
    TestRepo.update_all(query, set: [meta: %{world: "hello"}])
    assert TestRepo.get!(Post, post._key).meta == %{"world" => "hello"}
  end

  @tag :map_type
  test "embeds one" do
    item = %Item{price: 123, valid_at: ~D[2014-01-16]}
    order =
      %Order{}
      |> Ecto.Changeset.change
      |> Ecto.Changeset.put_embed(:item, item)
    order = TestRepo.insert!(order)
    dbitem = TestRepo.get!(Order, order._key).item
    assert item.price == dbitem.price
    assert item.valid_at == dbitem.valid_at

    [dbitem] = TestRepo.all(from o in Order, select: o.item)
    assert item.price == dbitem.price
    assert item.valid_at == dbitem.valid_at

    {1, _} = TestRepo.update_all(Order, set: [item: %{dbitem | price: 456}])
    assert TestRepo.get!(Order, order._key).item.price == 456
  end

  @tag :map_type
  @tag :array_type
  test "embeds many" do
    item = %Item{price: 123, valid_at: ~D[2014-01-16]}
    tag =
      %Tag{}
      |> Ecto.Changeset.change
      |> Ecto.Changeset.put_embed(:items, [item])
    tag = TestRepo.insert!(tag)

    [dbitem] = TestRepo.get!(Tag, tag._key).items
    assert item.price == dbitem.price
    assert item.valid_at == dbitem.valid_at

    [[dbitem]] = TestRepo.all(from t in Tag, select: t.items)
    assert item.price == dbitem.price
    assert item.valid_at == dbitem.valid_at

    {1, _} = TestRepo.update_all(Tag, set: [items: [%{dbitem | price: 456}]])
    assert (TestRepo.get!(Tag, tag._key).items |> hd).price == 456
  end

  # TODO
  @tag :decimal_type
  test "decimal type" do
#   decimal = Decimal.new("1.0")

#   TestRepo.insert!(%Post{cost: decimal})
#
#   assert [^decimal] = TestRepo.all(from p in Post, where: p.cost == ^decimal, select: p.cost)
#   assert [^decimal] = TestRepo.all(from p in Post, where: p.cost == ^1.0, select: p.cost)
#   assert [^decimal] = TestRepo.all(from p in Post, where: p.cost == ^1, select: p.cost)
#   assert [^decimal] = TestRepo.all(from p in Post, where: p.cost == 1.0, select: p.cost)
#   assert [^decimal] = TestRepo.all(from p in Post, where: p.cost == 1, select: p.cost)
  end

  # TODO
  test "schemaless types" do
#    datetime = ~N[2014-01-16 20:26:51]
#    assert {1, _} =
#           TestRepo.insert_all("posts", [[inserted_at: datetime]])
#    assert {1, _} =
#           TestRepo.update_all("posts", set: [inserted_at: datetime])
#    assert [_] =
#           TestRepo.all(from p in "posts", where: p.inserted_at >= ^datetime, select: p.inserted_at)
#    assert [_] =
#           TestRepo.all(from p in "posts", where: p.inserted_at in [^datetime], select: p.inserted_at)
#    assert [_] =
#           TestRepo.all(from p in "posts", where: p.inserted_at in ^[datetime], select: p.inserted_at)
#
#    datetime = System.system_time(:seconds) * 1_000_000 |> DateTime.from_unix!(:microseconds)
#    assert {1, _} =
#           TestRepo.insert_all("users", [[inserted_at: datetime, updated_at: datetime]])
#    assert {1, _} =
#           TestRepo.update_all("users", set: [inserted_at: datetime])
#    assert [_] =
#           TestRepo.all(from u in "users", where: u.inserted_at >= ^datetime, select: u.updated_at)
#    assert [_] =
#           TestRepo.all(from u in "users", where: u.inserted_at in [^datetime], select: u.updated_at)
#    assert [_] =
#           TestRepo.all(from u in "users", where: u.inserted_at in ^[datetime], select: u.updated_at)
  end
end

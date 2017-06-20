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
end
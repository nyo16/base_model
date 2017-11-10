defmodule BaseModelSpec do
  use ESpec
  import ShorterMaps
  use ExampleApp

  before do
    # set up a sandbox DB connection for each test.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExampleApp.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(ExampleApp.Repo, {:shared, self()})
  end
  finally do
    # reset the database
    Ecto.Adapters.SQL.Sandbox.checkin(ExampleApp.Repo)
  end

  describe "all" do
    it "returns an empty list when there are none" do
      User.all |> should(eq [])
    end

    it "returns all records in the db if there are any" do
      User.create(name: "a")
      User.create(name: "b")
      User.all |> should(match_pattern [%User{name: "a"}, %User{name: "b"}])
    end

    it "supports :preload" do
      {:ok, ~M{id} = a} = User.create(name: "a")
      Problem.create(description: "b", user: a)
      User.all(preload: :problems)
      |> should(match_pattern [%User{name: "a", problems: [%Problem{description: "b"}]}])
    end

    it "allows specifying sort order" do
      User.create(name: "b")
      User.create(name: "a")
      User.create(name: "c")
      User.all(order_by: :name)
      |> should(match_pattern [%User{name: "a"}, %User{name: "b"}, %User{name: "c"}])

      User.all(order_by: [desc: :name])
      |> should(match_pattern [%User{name: "c"}, %User{name: "b"}, %User{name: "a"}])
    end
  end

  describe "create" do
    it "returns {:ok, model} if it succeeds" do
      User.create(name: "Chris", age: -1) |> should(match_pattern {:ok, %User{name: "Chris", age: -1}})
    end

    it "accepts a map" do
      {name, age} = {"test_map_create", 1999}
      User.create(~M{name, age}) |> should(match_pattern {:ok, %User{name: ^name, age: ^age}})
    end

    it "allows setting an association" do
      {:ok, ~M{id} = bob} = User.create(name: "bob")
      {:ok, problem} = Problem.create(user: bob, desciption: "a problem")
      User.find(id, preload: :problems) |> should(match_pattern %User{name: "bob", problems: [problem]})
    end

    it "returns {:error, reason} if it fails"
    it "allows overriding validation"
  end

  describe "find" do
    it "returns nil if the id is not in the table" do
      User.find(1) |> should(eq nil)
    end

    it "returns the record if it exists" do
      {:ok, ~M{id}} = User.create(name: "test_find")
      User.find(id) |> should(match_pattern(%User{name: "test_find"}))
    end

    xit "can accept a list of pks" do
      {:ok, ~M{id}} = User.create(name: "test_find")
      {:ok, %{id: id2}} = User.create(name: "test_find2")
      User.find([id, id2]) |> should(match_pattern([%User{name: "test_find"}, %User{name: "test_find2"}]))
    end
  end

  describe "where(where_clause, opts)" do
    before do
      {:ok, a} = User.create(name: "a", age: 1)
      User.create(name: "b", age: 2)
      User.create(name: "c", age: 2)
      Problem.create(description: "problem for a", user: a)
    end

    it "returns a list of matching records" do
      User.where(age: 1) |> should(match_pattern [%User{name: "a", age: 1}])
    end

    it "allows specifying order" do
      User.where([age: 2], order_by: :name) |> should(match_pattern [%User{name: "b", age: 2}, %User{name: "c", age: 2}])
      User.where([age: 2], order_by: [desc: :name]) |> should(match_pattern [%User{name: "c", age: 2}, %User{name: "b", age: 2}])
    end

    it "allows specifying limit" do
      User.where([age: 2], limit: 1) |> should(match_pattern [%User{age: 2}])
    end

    it "supports :preload" do
      User.where([age: 1], preload: :problems)
      |> should(match_pattern [%User{name: "a", problems: [%Problem{description: "problem for a"}]}])
    end

    it "ignores other opts" do
      User.where([age: 2], asdfasdf: 1, limit: 1) |> should(match_pattern [%User{age: 2}])
    end

    it "allows querying by association" do
      [a] = User.where(name: "a")
      Problem.where(user: a)
      |> should(match_pattern [%Problem{description: "problem for a"}])
    end
  end

  describe "count(where_clause)" do
    it "returns the count of all records with no query" do
      User.count |> should(eq 0)
      User.create(name: "a")
      User.count |> should(eq 1)
    end

    it "accepts associations in the query" do
      {:ok, a} = User.create(name: "a")
      {:ok, b} = Problem.create(user: a, description: "b")
      Problem.count(user: a) |> should(eq 1)
    end

    it "returns the count of matching records" do
      User.create(name: "a")
      User.create(name: "a")
      User.create(name: "b")
      User.count(name: "a") |> should(eq 2)
      User.count(name: "b") |> should(eq 1)
    end

  end

  describe "update(model, params)" do
    it "updates the model" do
      {:ok, ~M{id} = model} = User.create(name: "a")
      User.update(model, name: "b")
      User.find(id) |> should(match_pattern %User{name: "b"})
    end

    it "returns {:ok, updated_model} when successful" do
      {:ok, ~M{id} = model} = User.create(name: "a")
      User.update(model, name: "b", age: 12)
      |> should(match_pattern {:ok, %User{name: "b", age: 12}})
      User.find(id) |> should(match_pattern %User{name: "b", age: 12})
    end

    it "supports updating association" do
      {:ok, a} = User.create(name: "a")
      {:ok, b} = User.create(name: "b")
      {:ok, c} = Problem.create(user: a, description: "c")
      Problem.update(c, user: b)
      Problem.count(user: b) |> should(eq 1)
    end

    it "allows overriding validation"
  end

  describe "update_where(where_clause, update_map)" do
    before do
      User.create(name: "a")
      User.create(name: "a")
      User.create(name: "b")
    end

    it "updates all the matching records" do
      User.update_where([name: "a"], name: "c")
      User.count(name: "c") |> should(eq 2)
      User.count(name: "a") |> should(eq 0)
    end

    it "returns {:ok, count} if successful" do
      User.update_where([name: "a"], name: "c")
      |> should(eq {:ok, 2})
    end

    it "allows using assoc in where and in update" do
      [%{id: id1}=user1, %{id: id2}=user2] = User.where(name: "a")
      Problem.create(user: user1, description: "first problem")
      Problem.create(user: user1, description: "second problem")
      Problem.create(user: user2, description: "third problem")
      Problem.update_where([user: user1], [user: user2])
      Problem.count(user: user2) |> should(eq 3)
    end

  end


  describe "delete(id)" do
    it "deletes a record" do
      {:ok, ~M{id}} = User.create(age: 1, name: "a")
      User.count |> should(eq 1)
      User.delete(id)
      User.count |> should(eq 0)
    end

    it "returns :ok if the record was deleted" do
      {:ok, ~M{id}} = User.create(age: 1, name: "a")
      User.delete(id) |> should(eq :ok)
    end

    it "returns {:error, reason} if there was a problem" do
      User.delete(1) |> should(eq {:error, :not_found})
    end
  end


  describe "delete_where(where_clause)" do
    before do
      User.create(name: "a")
      User.create(name: "a")
      User.create(name: "b")

    end

    it "deletes all records that match" do
      User.delete_where(name: "a")
      User.count |> should(eq 1)
    end

    it "returns {:ok, count} if successful" do
      User.delete_where(name: "a") |> should(eq {:ok, 2})
      User.delete_where(name: "b") |> should(eq {:ok, 1})
      User.delete_where(name: "c") |> should(eq {:ok, 0})
    end

    it "allows using assoc" do
      [b] = User.where(name: "b")
      Problem.create(user: b, description: "c")
      Problem.delete_where(user: b)
      Problem.count |> should eq 0
    end
  end

  describe "delete_all()" do
    before do
      User.create(name: "a")
      User.create(name: "a")
      User.create(name: "b")
    end

    it "deletes all records in the table" do
      User.delete_all()
      User.count |> should(eq 0)
    end

    it "returns {:ok, count}" do
      User.delete_all() |> should(eq {:ok, 3})
    end
  end

  describe "first(where_clause, opts)" do
    it "returns one matching row in the table"
    it "supports :preload"
    it "supports :order_by"
    it "supports associations"
    it "returns nil when no matches"
  end

  describe "first_or_create(where_clause)" do
    it "returns the first matching item if one exists"
    it "supports :preload"
    it "supports :order_by"
    it "supports associations"
    it "creates a new object if one does not exist"
  end

end
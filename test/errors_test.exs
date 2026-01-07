defmodule ErrorsTest do
  @moduledoc """
  every new error, and related tests
  """
  use ExUnit.Case, async: true

  @simple_map %{foo: "bar", bolt_sips: true}
  @nested_map %{
    foo: "bar",
    bolt_sips: true,
    a_map: %{unu: 1, doi: 2, baz: "foo"},
    a_list: [1, 2, 3.14]
  }

  test "create a node using SET properties and a simple map" do
    %Bolt.Swigs.Response{stats: stats, type: type} =
      Bolt.Swigs.query!(Bolt.Swigs.conn(), "CREATE (report:Report) SET report = $props", %{
        props: @simple_map
      })

    assert %{"labels-added" => 1, "nodes-created" => 1, "properties-set" => 2} == stats
    assert "w" == type
  end

  test "exception when creating a node using SET properties with a nested map" do
    err = "Property values can only be of primitive types or arrays thereof"

    assert_raise Bolt.Swigs.Exception, err, fn ->
      Bolt.Swigs.query!(
        Bolt.Swigs.conn(),
        "CREATE (report:Report) SET report = $props",
        %{props: @nested_map}
      )
    end
  end

  test "exception when creating a node using SET properties with a list" do
    assert_raise Bolt.Swigs.Exception, fn ->
      Bolt.Swigs.query!(Bolt.Swigs.conn(), "CREATE (report:Report) SET report = $props", %{
        props: ["foo", "bar"]
      })
    end
  end
end

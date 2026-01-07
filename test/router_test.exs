defmodule Bolt.Swigs.Routing.RouterTest do
  use ExUnit.Case
  doctest Bolt.Swigs.Router

  alias Bolt.Swigs.Response

  # @routing_table %{
  #   "servers" => [
  #     %{"addresses" => ["localhost:7687"], "role" => "WRITE"},
  #     %{"addresses" => ["localhost:7688", "localhost:7689"], "role" => "READ"},
  #     %{
  #       "addresses" => ["localhost:7688", "localhost:7687", "localhost:7689"],
  #       "role" => "ROUTE"
  #     }
  #   ],
  #   "ttl" => 300
  # }

  # @connections %{
  #   read: %{"localhost:7688" => 0, "localhost:7689" => 0},
  #   route: %{
  #     "localhost:7687" => 0,
  #     "localhost:7688" => 0,
  #     "localhost:7689" => 0
  #   },
  #   write: %{"localhost:7687" => 0},
  #   ttl: 300
  # }

  @router_address "bolt+routing://localhost:7687?key=value,foo=bar;policy=EU"

  @bolt_sips_config [
    url: @router_address,
    ssl: true
  ]

  @role_based_configuration [
    url: "bolt://localhost",
    basic_auth: [username: "neo4j", password: "test"],
    pool_size: 10,
    max_overflow: 2,
    role: :zorba
  ]

  describe "Role based configuration" do
    test "context attributes for routed connections" do
      conf = Bolt.Swigs.Utils.default_config(@bolt_sips_config)

      assert "bolt+routing" == conf[:schema]
      assert "key=value,foo=bar;policy=EU" == conf[:query]
      assert %{"key" => "value", "foo" => "bar", "policy" => "EU"} == conf[:routing_context]
    end

    test "user defined ad-hoc roles for standard (community) instances" do
      assert {:ok, _pid} = Bolt.Swigs.start_link(@role_based_configuration)
      assert conn = Bolt.Swigs.conn(@role_based_configuration[:role])
      assert %Response{results: [%{"n" => 1}]} = Bolt.Swigs.query!(conn, "RETURN 1 as n")
    end

    test "user defined ad-hoc roles can coexist, and act as distinct connection pools" do
      assert {:ok, pid1} =
               @role_based_configuration
               |> Keyword.put(:role, :alpha)
               |> Bolt.Swigs.start_link()

      assert conn1 = Bolt.Swigs.conn(:alpha)
      assert %Response{results: [%{"n" => 1}]} = Bolt.Swigs.query!(conn1, "RETURN 1 as n")

      assert {:ok, pid2} = Bolt.Swigs.start_link(@role_based_configuration)
      assert pid1 == pid2

      assert conn2 = Bolt.Swigs.conn(@role_based_configuration[:role])
      refute conn1 == conn2

      assert %Response{results: [%{"n" => 1}]} = Bolt.Swigs.query!(conn2, "RETURN 1 as n")

      assert %{
               default: %{
                 connections: %{
                   alpha: %{"localhost:7687" => 0},
                   direct: %{"localhost:7687" => 0},
                   routing_query: nil,
                   zorba: %{"localhost:7687" => 0}
                 }
               }
             } = Bolt.Swigs.info()

      assert :ok == Bolt.Swigs.terminate_connections(:alpha)

      assert_raise Bolt.Swigs.Exception,
                   "no connection exists with this role: alpha (prefix: default)",
                   fn -> Bolt.Swigs.conn(:alpha) end

      refute Map.has_key?(Bolt.Swigs.info(), :alpha)
    end
  end
end

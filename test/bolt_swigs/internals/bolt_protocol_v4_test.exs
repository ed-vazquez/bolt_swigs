defmodule Bolt.Swigs.Internals.BoltProtocolV4Test do
  use ExUnit.Case, async: true
  @moduletag :bolt_v4

  alias Bolt.Swigs.Internals.BoltProtocol
  alias Bolt.Swigs.Internals.BoltProtocolV4
  alias Bolt.Swigs.Metadata

  setup do
    app_config = Application.get_env(:bolt_swigs, Bolt)

    port = Keyword.get(app_config, :port, 7687)
    auth = {app_config[:basic_auth][:username], app_config[:basic_auth][:password]}

    config =
      app_config
      |> Keyword.put(:port, port)
      |> Keyword.put(:auth, auth)
      |> Bolt.Swigs.Utils.default_config()

    {:ok, port} =
      config[:hostname]
      |> String.to_charlist()
      |> :gen_tcp.connect(config[:port],
        active: false,
        mode: :binary,
        packet: :raw
      )

    {:ok, _} = BoltProtocol.handshake(:gen_tcp, port, [])

    on_exit(fn ->
      :gen_tcp.close(port)
    end)

    {:ok, config: config, port: port}
  end

  describe "hello/5:" do
    test "ok", %{config: config, port: port} do
      assert {:ok, _} =
               BoltProtocolV4.hello(
                 :gen_tcp,
                 port,
                 4,
                 config[:auth],
                 []
               )
    end

    test "invalid auth", %{config: config, port: port} do
      assert {:error, _} =
               BoltProtocolV4.hello(
                 :gen_tcp,
                 port,
                 4,
                 {config[:basic_auth][:username], "wrong!"},
                 []
               )
    end
  end

  test "goodbye/3", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

    assert :ok = BoltProtocolV4.goodbye(:gen_tcp, port, 4)
  end

  describe "run/7:" do
    test "ok without parameters nor metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])
    end

    test "ok without parameters with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{tx_timeout: 10_000})

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, metadata, [])
    end

    test "ok with parameters without metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN $num AS num", %{num: 5}, %{}, [])
    end

    test "ok with parameters with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{tx_timeout: 10_000})

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(
                 :gen_tcp,
                 port,
                 4,
                 "RETURN $num AS num",
                 %{num: 5},
                 metadata,
                 []
               )
    end

    test "returns IGNORED when sending RUN on a FAILURE state", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])
      assert {:error, _} = BoltProtocolV4.run(:gen_tcp, port, 4, "Invalid cypher", %{}, %{}, [])

      assert {:error, _} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
    end

    test "ok after IGNORED and RESET", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])
      assert {:error, _} = BoltProtocolV4.run(:gen_tcp, port, 4, "Invalid cypher", %{}, %{}, [])

      assert {:error, _} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      :ok = BoltProtocol.reset(:gen_tcp, port, 4, [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, results} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      assert [{:record, [1]}, {:success, _}] = results
    end
  end

  test "run_statement/7 (successful)", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

    assert [_ | _] =
             BoltProtocolV4.run_statement(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])
  end

  describe "pull/5:" do
    test "pull all records (n: -1)", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, results} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      assert [{:record, [1]}, {:success, _}] = results
    end

    test "pull with batch size", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"n">>]}}} =
               BoltProtocolV4.run(
                 :gen_tcp,
                 port,
                 4,
                 "UNWIND range(1, 10) AS n RETURN n",
                 %{},
                 %{},
                 []
               )

      # Pull first 5 records
      assert {:ok, results} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: 5}, [])
      records = Enum.filter(results, fn {type, _} -> type == :record end)
      assert length(records) == 5

      # Pull remaining records
      assert {:ok, results} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      remaining_records = Enum.filter(results, fn {type, _} -> type == :record end)
      assert length(remaining_records) == 5
    end
  end

  describe "discard/5:" do
    test "discard all records (n: -1)", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert :ok = BoltProtocolV4.discard(:gen_tcp, port, 4, %{n: -1}, [])
    end

    test "discard with batch size", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"n">>]}}} =
               BoltProtocolV4.run(
                 :gen_tcp,
                 port,
                 4,
                 "UNWIND range(1, 10) AS n RETURN n",
                 %{},
                 %{},
                 []
               )

      # Discard first 5 records
      assert :ok = BoltProtocolV4.discard(:gen_tcp, port, 4, %{n: 5}, [])

      # Pull remaining records to verify discard worked
      assert {:ok, results} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      records = Enum.filter(results, fn {type, _} -> type == :record end)
      assert length(records) == 5
    end
  end

  test "reset/4 (successful)", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

    assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
             BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

    assert :ok = BoltProtocol.reset(:gen_tcp, port, 4, [])
  end

  describe "Transaction management" do
    test "Open a transaction without metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      {:ok, _} = BoltProtocolV4.begin(:gen_tcp, port, 4, %{}, [])
    end

    # Work only with Neo4j Enterprise
    @tag :enterprise
    test "Open a transaction with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{bookmarks: ["neo4j:bookmark:v1:tx234"], tx_timeout: 1_000})

      {:ok, _} = BoltProtocolV4.begin(:gen_tcp, port, 4, metadata, [])
    end

    test "Commit a transaction", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      {:ok, _} = BoltProtocolV4.begin(:gen_tcp, port, 4, %{}, [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, _} = BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      # Memgraph may return empty map instead of bookmark
      assert {:ok, metadata} = BoltProtocolV4.commit(:gen_tcp, port, 4, [])
      assert is_map(metadata)
    end

    test "Rollback a transaction", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      {:ok, _} = BoltProtocolV4.begin(:gen_tcp, port, 4, %{}, [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      BoltProtocolV4.discard(:gen_tcp, port, 4, %{n: -1}, [])
      assert :ok = BoltProtocolV4.rollback(:gen_tcp, port, 4, [])
    end

    # It works with Neo4j Enterprise only
    @tag :enterprise
    test "With socket instead of gen_tcp", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(Bolt.Swigs.Socket, port, 4, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{bookmarks: ["neo4j:bookmark:v1:tx234"], tx_timeout: 1_000})

      {:ok, _} = BoltProtocolV4.begin(Bolt.Swigs.Socket, port, 4, metadata, [])
    end
  end

  describe "Backward compatibility with pull_all/discard_all" do
    test "pull_all works via BoltProtocol delegation", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, results} = BoltProtocol.pull_all(:gen_tcp, port, 4, [])
      assert [{:record, [1]}, {:success, _}] = results
    end

    test "discard_all works via BoltProtocol delegation", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV4.hello(:gen_tcp, port, 4, config[:auth], [])

      assert {:ok, {:success, %{"fields" => [<<"num">>]}}} =
               BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN 1 AS num", %{}, %{}, [])

      assert :ok = BoltProtocol.discard_all(:gen_tcp, port, 4, [])
    end
  end
end

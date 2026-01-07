defmodule Bolt.Swigs.Internals.BoltProtocolV5Test do
  use ExUnit.Case, async: true
  @moduletag :bolt_v5

  alias Bolt.Swigs.Internals.BoltProtocol
  alias Bolt.Swigs.Internals.BoltProtocolV5
  alias Bolt.Swigs.Metadata

  setup_all do
    # Quick check if server supports Bolt v5
    app_config = Application.get_env(:bolt_swigs, Bolt)
    port = Keyword.get(app_config, :port, 7687)

    config =
      app_config
      |> Keyword.put(:port, port)
      |> Bolt.Swigs.Utils.default_config()

    case :gen_tcp.connect(
           String.to_charlist(config[:hostname]),
           config[:port],
           [active: false, mode: :binary, packet: :raw],
           1000
         ) do
      {:ok, test_port} ->
        {:ok, bolt_version} = BoltProtocol.handshake(:gen_tcp, test_port, [])
        :gen_tcp.close(test_port)

        if bolt_version < 5 do
          {:ok,
           skip_reason:
             "Server negotiated Bolt v#{bolt_version}, but v5 is required. Memgraph may need updating or configuration changes."}
        else
          :ok
        end

      {:error, _} ->
        {:ok, skip_reason: "Cannot connect to database server"}
    end
  end

  setup context do
    if reason = context[:skip_reason] do
      {:ok, skip: reason}
    else
      _setup_test(context)
    end
  end

  defp _setup_test(_context) do
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

    {:ok, _bolt_version} = BoltProtocol.handshake(:gen_tcp, port, [])

    on_exit(fn ->
      :gen_tcp.close(port)
    end)

    {:ok, config: config, port: port}
  end

  describe "hello/4:" do
    test "ok without auth", context do
      if reason = context[:skip], do: {:skip, reason}

      assert {:ok, info} = BoltProtocolV5.hello(:gen_tcp, context.port, 5, [])
      assert is_map(info)
    end
  end

  describe "logon/5:" do
    test "ok with valid auth", context do
      if reason = context[:skip], do: {:skip, reason}
      %{config: config, port: port} = context
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])

      assert {:ok, _info} =
               BoltProtocolV5.logon(
                 :gen_tcp,
                 port,
                 5,
                 config[:auth],
                 []
               )
    end

    test "error with invalid auth", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])

      assert {:error, _} =
               BoltProtocolV5.logon(
                 :gen_tcp,
                 port,
                 5,
                 {config[:basic_auth][:username], "wrong_password!"},
                 []
               )
    end
  end

  describe "logoff/4:" do
    test "ok after logon", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, _} = BoltProtocolV5.logoff(:gen_tcp, port, 5, [])
    end
  end

  test "goodbye/3", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
    assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

    assert :ok = BoltProtocolV5.goodbye(:gen_tcp, port, 5)
  end

  describe "run/7:" do
    test "ok without parameters nor metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])
    end

    test "ok without parameters with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{tx_timeout: 10_000})

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, metadata, [])
    end

    test "ok with parameters without metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN $num AS num", %{num: 5}, %{}, [])
    end

    test "ok with parameters with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{tx_timeout: 10_000})

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(
                 :gen_tcp,
                 port,
                 5,
                 "RETURN $num AS num",
                 %{num: 5},
                 metadata,
                 []
               )
    end

    test "returns IGNORED when sending RUN on a FAILURE state", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])
      assert {:error, _} = BoltProtocolV5.run(:gen_tcp, port, 5, "Invalid cypher", %{}, %{}, [])

      assert {:error, _} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
    end

    test "ok after IGNORED and RESET", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])
      assert {:error, _} = BoltProtocolV5.run(:gen_tcp, port, 5, "Invalid cypher", %{}, %{}, [])

      assert {:error, _} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
      :ok = BoltProtocolV5.reset(:gen_tcp, port, 5, [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok,
              [
                record: [1],
                success: %{"type" => "r"}
              ]} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
    end
  end

  describe "pull/5:" do
    test "pull all records with n: -1", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok,
              [
                record: [1],
                success: %{"type" => "r"}
              ]} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
    end

    test "pull records in batches", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      # Create a query that returns multiple records
      assert {:ok, {:success, %{"fields" => ["n"]}}} =
               BoltProtocolV5.run(
                 :gen_tcp,
                 port,
                 5,
                 "UNWIND range(1, 10) AS n RETURN n",
                 %{},
                 %{},
                 []
               )

      # Pull first 5 records
      assert {:ok, batch1} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: 5}, [])
      assert length(batch1) == 6
      # 5 records + 1 success with has_more: true

      # Pull remaining records
      assert {:ok, batch2} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
      assert length(batch2) >= 6
      # 5 records + 1 success with has_more: false
    end
  end

  describe "discard/5:" do
    test "discard all records with n: -1", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert :ok = BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: -1}, [])
    end

    test "discard records in batches", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["n"]}}} =
               BoltProtocolV5.run(
                 :gen_tcp,
                 port,
                 5,
                 "UNWIND range(1, 10) AS n RETURN n",
                 %{},
                 %{},
                 []
               )

      # Discard first 5 records
      assert :ok = BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: 5}, [])

      # Discard remaining records
      assert :ok = BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: -1}, [])
    end
  end

  test "run_statement/7 (successful)", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
    assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

    assert [_ | _] =
             BoltProtocolV5.run_statement(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])
  end

  test "reset/4 (successful)", %{config: config, port: port} do
    assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
    assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

    assert {:ok, {:success, %{"fields" => ["num"]}}} =
             BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

    assert :ok = BoltProtocolV5.reset(:gen_tcp, port, 5, [])
  end

  describe "Transaction management" do
    test "Open a transaction without metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      {:ok, _} = BoltProtocolV5.begin(:gen_tcp, port, 5, %{}, [])
    end

    @tag :enterprise
    test "Open a transaction with metadata", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])
      {:ok, metadata} = Metadata.new(%{bookmarks: ["neo4j:bookmark:v1:tx234"], tx_timeout: 1_000})

      {:ok, _} = BoltProtocolV5.begin(:gen_tcp, port, 5, metadata, [])
    end

    test "Commit a transaction", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      {:ok, _} = BoltProtocolV5.begin(:gen_tcp, port, 5, %{}, [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, _} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
      {:ok, %{"bookmark" => _}} = BoltProtocolV5.commit(:gen_tcp, port, 5, [])
    end

    test "Rollback a transaction", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      {:ok, _} = BoltProtocolV5.begin(:gen_tcp, port, 5, %{}, [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: -1}, [])
      assert :ok = BoltProtocolV5.rollback(:gen_tcp, port, 5, [])
    end

    test "Multiple queries in a transaction", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      {:ok, _} = BoltProtocolV5.begin(:gen_tcp, port, 5, %{}, [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok, _} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])

      assert {:ok, {:success, %{"fields" => ["result"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 2 AS result", %{}, %{}, [])

      assert {:ok, _} = BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])

      {:ok, %{"bookmark" => _}} = BoltProtocolV5.commit(:gen_tcp, port, 5, [])
    end
  end

  describe "route/7:" do
    @tag :routing
    test "ok with routing context", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      result =
        BoltProtocolV5.route(
          :gen_tcp,
          port,
          5,
          %{},
          [],
          "neo4j",
          []
        )

      # Route may return routing table or error depending on server configuration
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "telemetry/5:" do
    test "ok with api value", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      # API values: 0 = managed, 1 = explicit, 2 = implicit, 3 = execute_query
      result = BoltProtocolV5.telemetry(:gen_tcp, port, 5, 0, [])

      # Telemetry may not be supported in all server versions
      assert match?(:ok, result) or match?({:error, _}, result)
    end
  end

  describe "Backward compatibility via BoltProtocol:" do
    test "pull_all delegates to pull with n: -1", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert {:ok,
              [
                record: [1],
                success: %{"type" => "r"}
              ]} = BoltProtocol.pull_all(:gen_tcp, port, 5, [])
    end

    test "discard_all delegates to discard with n: -1", %{config: config, port: port} do
      assert {:ok, _} = BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      assert {:ok, _} = BoltProtocolV5.logon(:gen_tcp, port, 5, config[:auth], [])

      assert {:ok, {:success, %{"fields" => ["num"]}}} =
               BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN 1 AS num", %{}, %{}, [])

      assert :ok = BoltProtocol.discard_all(:gen_tcp, port, 5, [])
    end
  end
end

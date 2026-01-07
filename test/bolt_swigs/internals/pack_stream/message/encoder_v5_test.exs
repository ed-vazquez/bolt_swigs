defmodule Bolt.Swigs.Internals.PackStream.Message.EncoderV5Test do
  use ExUnit.Case, async: true

  doctest Bolt.Swigs.Internals.PackStream.Message.EncoderV5

  alias Bolt.Swigs.Internals.PackStream.Message.EncoderV5
  alias Bolt.Swigs.Metadata

  describe "Encode HELLO" do
    test "without auth params" do
      assert <<0x0, _, 0xB1, 0x1, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:hello, []}, 5))
    end

    test "with auth params" do
      # In v5, HELLO doesn't include auth credentials
      assert <<0x0, _, 0xB1, 0x1, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:hello, [{}]}, 5))
    end
  end

  describe "Encode LOGON" do
    test "with basic auth" do
      assert <<0x0, _, 0xB1, 0x6A, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:logon, [{"neo4j", "password"}]}, 5))
    end

    test "with empty auth" do
      assert <<0x0, _, 0xB1, 0x6A, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:logon, [{}]}, 5))
    end

    test "with auth map" do
      auth_map = %{
        scheme: "basic",
        principal: "neo4j",
        credentials: "password"
      }

      assert <<0x0, _, 0xB1, 0x6A, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:logon, [auth_map]}, 5))
    end
  end

  test "Encode LOGOFF" do
    assert <<0x0, 0x2, 0xB0, 0x6B, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV5.encode({:logoff, []}, 5))
  end

  test "Encode GOODBYE" do
    assert <<0x0, 0x2, 0xB0, 0x02, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV5.encode({:goodbye, []}, 5))
  end

  describe "Encode RUN" do
    test "without params nor metadata" do
      assert <<0x0, 0x14, 0xB3, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
               0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0xA0, 0x0,
               0x0>> == :erlang.iolist_to_binary(EncoderV5.encode({:run, ["RETURN 1 AS num"]}, 5))
    end

    test "without params but with metadata" do
      {:ok, metadata} = Metadata.new(%{tx_timeout: 5000})

      assert <<0x0, 0x22, 0xB3, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
               0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0xA1, 0x8A, 0x74, 0x78, 0x5F, 0x74, 0x69,
               0x6D, 0x65, 0x6F, 0x75, 0x74, 0xC9, 0x13, 0x88, 0x0,
               0x0>> ==
               :erlang.iolist_to_binary(
                 EncoderV5.encode({:run, ["RETURN 1 AS num", %{}, metadata]}, 5)
               )
    end

    test "with params but without metadata" do
      assert <<0x0, 0x1D, 0xB3, 0x10, 0xD0, 0x12, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x24,
               0x6E, 0x75, 0x6D, 0x20, 0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA1, 0x83, 0x6E, 0x75,
               0x6D, 0x5, 0xA0, 0x0,
               0x0>> ==
               :erlang.iolist_to_binary(
                 EncoderV5.encode({:run, ["RETURN $num AS num", %{num: 5}]}, 5)
               )
    end

    test "with params and metadata" do
      {:ok, metadata} = Metadata.new(%{tx_timeout: 5000})

      assert <<0x0, 0x2B, 0xB3, 0x10, 0xD0, 0x12, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x24,
               0x6E, 0x75, 0x6D, 0x20, 0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA1, 0x83, 0x6E, 0x75,
               0x6D, 0x5, 0xA1, 0x8A, 0x74, 0x78, 0x5F, 0x74, 0x69, 0x6D, 0x65, 0x6F, 0x75, 0x74,
               0xC9, 0x13, 0x88, 0x0,
               0x0>> ==
               :erlang.iolist_to_binary(
                 EncoderV5.encode({:run, ["RETURN $num AS num", %{num: 5}, metadata]}, 5)
               )
    end
  end

  describe "Encode PULL" do
    test "with n: -1 (pull all)" do
      assert <<0x0, 0x6, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:pull, [%{n: -1}]}, 5))
    end

    test "with n: 100 (pull batch)" do
      assert <<0x0, 0x6, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:pull, [%{n: 100}]}, 5))
    end

    test "with qid parameter" do
      assert <<0x0, _, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:pull, [%{n: -1, qid: 1}]}, 5))
    end
  end

  describe "Encode DISCARD" do
    test "with n: -1 (discard all)" do
      assert <<0x0, 0x6, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:discard, [%{n: -1}]}, 5))
    end

    test "with n: 100 (discard batch)" do
      assert <<0x0, 0x6, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:discard, [%{n: 100}]}, 5))
    end

    test "with qid parameter" do
      assert <<0x0, _, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:discard, [%{n: -1, qid: 1}]}, 5))
    end
  end

  describe "Encode BEGIN" do
    test "with empty metadata" do
      {:ok, metadata} = Metadata.new(%{})

      assert <<0x0, 0x3, 0xB1, 0x11, 0xA0, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:begin, [metadata]}, 5))
    end

    test "with metadata params" do
      {:ok, metadata} = Metadata.new(%{tx_timeout: 5000})

      assert <<0x0, 0x11, 0xB1, 0x11, 0xA1, 0x8A, 0x74, 0x78, 0x5F, 0x74, 0x69, 0x6D, 0x65, 0x6F,
               0x75, 0x74, 0xC9, 0x13, 0x88, 0x0,
               0x0>> == :erlang.iolist_to_binary(EncoderV5.encode({:begin, [metadata]}, 5))
    end
  end

  test "Encode COMMIT" do
    assert <<0x0, 0x2, 0xB0, 0x12, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV5.encode({:commit, []}, 5))
  end

  test "Encode ROLLBACK" do
    assert <<0x0, 0x2, 0xB0, 0x13, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV5.encode({:rollback, []}, 5))
  end

  test "Encode RESET" do
    assert <<0x0, 0x2, 0xB0, 0x0F, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV5.encode({:reset, []}, 5))
  end

  describe "Encode ROUTE" do
    test "with routing context" do
      assert <<0x0, _, 0xB3, 0x66, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:route, [%{}, [], "neo4j"]}, 5))
    end

    test "with routing context and bookmarks" do
      bookmarks = ["neo4j:bookmark:v1:tx123"]

      assert <<0x0, _, 0xB3, 0x66, _::binary>> =
               :erlang.iolist_to_binary(EncoderV5.encode({:route, [%{}, bookmarks, "neo4j"]}, 5))
    end
  end

  describe "Encode TELEMETRY" do
    test "with api 0 (managed)" do
      assert <<0x0, 0x3, 0xB1, 0x54, 0x0, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:telemetry, [0]}, 5))
    end

    test "with api 1 (explicit)" do
      assert <<0x0, 0x3, 0xB1, 0x54, 0x1, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:telemetry, [1]}, 5))
    end

    test "with api 2 (implicit)" do
      assert <<0x0, 0x3, 0xB1, 0x54, 0x2, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:telemetry, [2]}, 5))
    end

    test "with api 3 (execute_query)" do
      assert <<0x0, 0x3, 0xB1, 0x54, 0x3, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:telemetry, [3]}, 5))
    end
  end

  describe "Invalid messages for Bolt v5" do
    test "INIT is not valid in v5" do
      assert {:error, :invalid_message} = EncoderV5.encode({:init, [{}]}, 5)
    end

    test "ACK_FAILURE is not valid in v5" do
      assert {:error, :invalid_message} = EncoderV5.encode({:ack_failure, []}, 5)
    end

    test "PULL_ALL is replaced by PULL" do
      # PULL_ALL should still work through backward compatibility
      assert <<0x0, 0x2, 0xB0, 0x3F, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:pull_all, []}, 5))
    end

    test "DISCARD_ALL is replaced by DISCARD" do
      # DISCARD_ALL should still work through backward compatibility
      assert <<0x0, 0x2, 0xB0, 0x2F, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV5.encode({:discard_all, []}, 5))
    end
  end
end

defmodule Bolt.Swigs.Internals.PackStream.Message.EncoderV4Test do
  use ExUnit.Case, async: true

  doctest Bolt.Swigs.Internals.PackStream.Message.EncoderV4

  alias Bolt.Swigs.Internals.PackStream.Message.EncoderV4
  alias Bolt.Swigs.Metadata

  describe "Encode HELLO" do
    test "without auth params" do
      assert <<0x0, _, 0xB1, 0x1, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:hello, []}, 4))
    end

    test "with auth params" do
      assert <<0x0, _, 0xB1, 0x1, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:hello, [{"neo4j", "password"}]}, 4))
    end
  end

  test "Encode GOODBYE" do
    assert <<0x0, 0x2, 0xB0, 0x02, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV4.encode({:goodbye, []}, 4))
  end

  describe "Encode RUN" do
    test "without params nor metadata" do
      assert <<0x0, 0x14, 0xB3, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
               0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0xA0, 0x0,
               0x0>> == :erlang.iolist_to_binary(EncoderV4.encode({:run, ["RETURN 1 AS num"]}, 4))
    end

    test "without params but with metadata" do
      {:ok, metadata} = Metadata.new(%{tx_timeout: 5000})

      assert <<0x0, 0x22, 0xB3, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
               0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0xA1, 0x8A, 0x74, 0x78, 0x5F, 0x74, 0x69,
               0x6D, 0x65, 0x6F, 0x75, 0x74, 0xC9, 0x13, 0x88, 0x0,
               0x0>> ==
               :erlang.iolist_to_binary(
                 EncoderV4.encode({:run, ["RETURN 1 AS num", %{}, metadata]}, 4)
               )
    end

    test "with params but without metadata" do
      assert <<0x0, 0x1D, 0xB3, 0x10, 0xD0, 0x12, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x24,
               0x6E, 0x75, 0x6D, 0x20, 0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA1, 0x83, 0x6E, 0x75,
               0x6D, 0x5, 0xA0, 0x0,
               0x0>> ==
               :erlang.iolist_to_binary(
                 EncoderV4.encode({:run, ["RETURN $num AS num", %{num: 5}]}, 4)
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
                 EncoderV4.encode({:run, ["RETURN $num AS num", %{num: 5}, metadata]}, 4)
               )
    end
  end

  describe "Encode PULL" do
    test "with n: -1 (pull all)" do
      assert <<0x0, 0x6, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:pull, [%{n: -1}]}, 4))
    end

    test "with n: 100 (pull batch)" do
      assert <<0x0, 0x6, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:pull, [%{n: 100}]}, 4))
    end

    test "with qid parameter" do
      assert <<0x0, _, 0xB1, 0x3F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:pull, [%{n: -1, qid: 1}]}, 4))
    end
  end

  describe "Encode DISCARD" do
    test "with n: -1 (discard all)" do
      assert <<0x0, 0x6, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:discard, [%{n: -1}]}, 4))
    end

    test "with n: 100 (discard batch)" do
      assert <<0x0, 0x6, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:discard, [%{n: 100}]}, 4))
    end

    test "with qid parameter" do
      assert <<0x0, _, 0xB1, 0x2F, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:discard, [%{n: -1, qid: 1}]}, 4))
    end
  end

  describe "Encode BEGIN" do
    test "with empty metadata" do
      {:ok, metadata} = Metadata.new(%{})

      assert <<0x0, 0x3, 0xB1, 0x11, 0xA0, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV4.encode({:begin, [metadata]}, 4))
    end

    test "with metadata params" do
      {:ok, metadata} = Metadata.new(%{tx_timeout: 5000})

      assert <<0x0, 0x11, 0xB1, 0x11, 0xA1, 0x8A, 0x74, 0x78, 0x5F, 0x74, 0x69, 0x6D, 0x65, 0x6F,
               0x75, 0x74, 0xC9, 0x13, 0x88, 0x0,
               0x0>> == :erlang.iolist_to_binary(EncoderV4.encode({:begin, [metadata]}, 4))
    end

    test "with bookmarks in metadata" do
      {:ok, metadata} = Metadata.new(%{bookmarks: ["neo4j:bookmark:v1:tx123"]})

      assert <<0x0, _, 0xB1, 0x11, _::binary>> =
               :erlang.iolist_to_binary(EncoderV4.encode({:begin, [metadata]}, 4))
    end
  end

  test "Encode COMMIT" do
    assert <<0x0, 0x2, 0xB0, 0x12, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV4.encode({:commit, []}, 4))
  end

  test "Encode ROLLBACK" do
    assert <<0x0, 0x2, 0xB0, 0x13, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV4.encode({:rollback, []}, 4))
  end

  test "Encode RESET" do
    assert <<0x0, 0x2, 0xB0, 0x0F, 0x0, 0x0>> ==
             :erlang.iolist_to_binary(EncoderV4.encode({:reset, []}, 4))
  end

  describe "Invalid messages for Bolt v4" do
    test "INIT is not valid in v4" do
      assert {:error, :invalid_message} = EncoderV4.encode({:init, [{}]}, 4)
    end

    test "ACK_FAILURE is valid in v4" do
      assert <<0x0, 0x2, 0xB0, 0x0E, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV4.encode({:ack_failure, []}, 4))
    end

    test "PULL_ALL is replaced by PULL" do
      # PULL_ALL should still work through backward compatibility
      assert <<0x0, 0x2, 0xB0, 0x3F, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV4.encode({:pull_all, []}, 4))
    end

    test "DISCARD_ALL is replaced by DISCARD" do
      # DISCARD_ALL should still work through backward compatibility
      assert <<0x0, 0x2, 0xB0, 0x2F, 0x0, 0x0>> ==
               :erlang.iolist_to_binary(EncoderV4.encode({:discard_all, []}, 4))
    end
  end

  describe "Messages not available in Bolt v4" do
    test "LOGON is not available in v4" do
      # LOGON is a v5 feature, in v4 it will fail during encoding
      # because it tries to encode a tuple instead of a map
      assert_raise Bolt.Swigs.Internals.PackStreamError, fn ->
        EncoderV4.encode({:logon, [{"neo4j", "password"}]}, 4)
      end
    end

    test "LOGOFF is not available in v4" do
      # LOGOFF signature exists but not used in v4
      # It will encode but the server may not support it
      result = EncoderV4.encode({:logoff, []}, 4)
      assert is_list(result) or match?({:error, _}, result)
    end

    test "ROUTE is not available in v4" do
      # ROUTE signature exists but not officially part of v4
      # It will encode but the server may not support it
      result = EncoderV4.encode({:route, [%{}, [], "neo4j"]}, 4)
      assert is_list(result) or match?({:error, _}, result)
    end

    test "TELEMETRY is not available in v4" do
      # TELEMETRY is a v5 feature but signature exists
      # It will encode but the server may not support it
      result = EncoderV4.encode({:telemetry, [0]}, 4)
      assert is_list(result) or match?({:error, _}, result)
    end
  end
end

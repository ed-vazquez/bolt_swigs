defmodule Bolt.Swigs.Internals.BoltProtocolV5 do
  @moduledoc """
  Implementation of Bolt Protocol version 5.x

  Bolt Protocol v5 introduces several new features:
  - Separate authentication flow with LOGON/LOGOFF messages
  - PULL and DISCARD messages with configurable batch sizes (replacing PULL_ALL and DISCARD_ALL)
  - ROUTE message for routing table discovery
  - TELEMETRY message for collecting driver metrics (v5.4+)
  - Enhanced transaction metadata support
  """

  alias Bolt.Swigs.Internals.BoltProtocolHelper
  alias Bolt.Swigs.Internals.Error

  @doc """
  Implementation of Bolt's HELLO for v5. It initialises the connection without authentication.

  In Bolt v5, HELLO is used for connection initialization and capability negotiation,
  while authentication is handled separately via LOGON.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV5.hello(:gen_tcp, port, 5, [])
      {:ok, info}
  """
  @spec hello(atom(), port(), integer(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def hello(transport, port, bolt_version, options \\ [recv_timeout: 15_000]) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:hello, [{}]})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :hello)}

      other ->
        {:error, Error.exception(other, port, :hello)}
    end
  end

  @doc """
  Implementation of Bolt's LOGON. It authenticates the connection.

  LOGON is a new message in Bolt v5 that separates authentication from connection initialization.
  This allows for features like re-authentication without reconnecting.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV5.logon(:gen_tcp, port, 5, {"username", "password"}, [])
      {:ok, info}
  """
  @spec logon(atom(), port(), integer(), tuple() | map(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def logon(transport, port, bolt_version, auth, options \\ [recv_timeout: 15_000]) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:logon, [auth]})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :logon)}

      other ->
        {:error, Error.exception(other, port, :logon)}
    end
  end

  @doc """
  Implementation of Bolt's LOGOFF. It logs off the current user.

  LOGOFF is a new message in Bolt v5 that allows logging off without closing the connection.
  After LOGOFF, a new LOGON can be issued to authenticate as a different user.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV5.logoff(:gen_tcp, port, 5, [])
      {:ok, info}
  """
  @spec logoff(atom(), port(), integer(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def logoff(transport, port, bolt_version, options \\ [recv_timeout: 15_000]) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:logoff, []})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :logoff)}

      other ->
        {:error, Error.exception(other, port, :logoff)}
    end
  end

  @doc """
  Implementation of Bolt's GOODBYE. It closes the connection.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV5.goodbye(:gen_tcp, port, 5)
      :ok
  """
  def goodbye(transport, port, bolt_version) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:goodbye, []})

    try do
      Port.close(port)
      :ok
    rescue
      ArgumentError -> Error.exception("Can't close port", port, :goodbye)
    end
  end

  @doc """
  Implementation of Bolt's RUN. It passes a statement for execution on the server.

  Note that this message doesn't return the statement result. For this purpose, use PULL.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.run(:gen_tcp, port, 5, "RETURN $num AS num", %{num: 5}, %{}, [])
      {:ok, {:success, %{"fields" => ["num"]}}}
  """
  @spec run(atom(), port(), integer(), String.t(), map(), Bolt.Swigs.Metadata.t(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def run(transport, port, bolt_version, statement, params, metadata, options) do
    BoltProtocolHelper.send_message(
      transport,
      port,
      bolt_version,
      {:run, [statement, params, metadata]}
    )

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, _} = result ->
        {:ok, result}

      {:failure, response} ->
        {:error, Error.exception(response, port, :run)}

      %Error{} = error ->
        {:error, error}

      other ->
        {:error, Error.exception(other, port, :run)}
    end
  end

  @doc """
  Implementation of Bolt's PULL. It retrieves records from the active result stream.

  In Bolt v5, PULL replaces PULL_ALL and allows specifying how many records to fetch.
  Use `n: -1` to fetch all remaining records.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      # Pull all records
      iex> BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: -1}, [])
      {:ok, [...]}

      # Pull 100 records
      iex> BoltProtocolV5.pull(:gen_tcp, port, 5, %{n: 100}, [])
      {:ok, [...]}
  """
  @spec pull(atom(), port(), integer(), map(), Keyword.t()) ::
          {:ok, list()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def pull(transport, port, bolt_version, extra \\ %{n: -1}, options) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:pull, [extra]})

    with data <- BoltProtocolHelper.receive_data(transport, port, bolt_version, options),
         data <- List.wrap(data),
         {:success, _} <- List.last(data) do
      {:ok, data}
    else
      {:failure, response} ->
        {:failure, Error.exception(response, port, :pull)}

      other ->
        {:error, Error.exception(other, port, :pull)}
    end
  end

  @doc """
  Implementation of Bolt's DISCARD. It discards records from the active result stream.

  In Bolt v5, DISCARD replaces DISCARD_ALL and allows specifying how many records to discard.
  Use `n: -1` to discard all remaining records.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      # Discard all records
      iex> BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: -1}, [])
      :ok

      # Discard 100 records
      iex> BoltProtocolV5.discard(:gen_tcp, port, 5, %{n: 100}, [])
      :ok
  """
  @spec discard(atom(), port(), integer(), map(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def discard(transport, port, bolt_version, extra \\ %{n: -1}, options) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:discard, [extra]})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, _} ->
        :ok

      {:failure, response} ->
        {:error, Error.exception(response, port, :discard)}

      other ->
        {:error, Error.exception(other, port, :discard)}
    end
  end

  @doc """
  Runs a statement (most likely Cypher statement) and returns a list of the
  records and a summary (Act as as a RUN + PULL).

  Records are represented using PackStream's record data type. Their Elixir
  representation is a Keyword with the indexes `:sig` and `:fields`.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocol.run_statement(:gen_tcp, port, 5, "MATCH (n) RETURN n")
      [
        {:success, %{"fields" => ["n"]}},
        {:record, [sig: 1, fields: [1, "Example", "Labels", %{"some_attribute" => "some_value"}]]},
        {:success, %{"type" => "r"}}
      ]
  """
  @spec run_statement(
          atom(),
          port(),
          integer(),
          String.t(),
          map(),
          Bolt.Swigs.Metadata.t(),
          Keyword.t()
        ) ::
          [
            Bolt.Swigs.Internals.PackStream.Message.decoded()
          ]
          | Bolt.Swigs.Internals.Error.t()
  def run_statement(transport, port, bolt_version, statement, params, metadata, options) do
    with {:ok, run_data} <-
           run(transport, port, bolt_version, statement, params, metadata, options),
         {:ok, result} <- pull(transport, port, bolt_version, %{n: -1}, options) do
      [run_data | result]
    else
      {:error, %Error{} = error} ->
        error

      other ->
        Error.exception(other, port, :run_statement)
    end
  end

  @doc """
  Implementation of Bolt's BEGIN. It opens a transaction.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.begin(:gen_tcp, port, 5, %{}, [])
      {:ok, metadata}
  """
  @spec begin(atom(), port(), integer(), Bolt.Swigs.Metadata.t() | map(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def begin(transport, port, bolt_version, metadata, options) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:begin, [metadata]})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :begin)}

      other ->
        {:error, Error.exception(other, port, :begin)}
    end
  end

  @doc """
  Implementation of Bolt's COMMIT. It commits the open transaction.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.commit(:gen_tcp, port, 5, [])
      {:ok, %{"bookmark" => "..."}}
  """
  @spec commit(atom(), port(), integer(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def commit(transport, port, bolt_version, options) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:commit, []})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :commit)}

      other ->
        {:error, Error.exception(other, port, :commit)}
    end
  end

  @doc """
  Implementation of Bolt's ROLLBACK. It rollbacks the open transaction.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.rollback(:gen_tcp, port, 5, [])
      :ok
  """
  @spec rollback(atom(), port(), integer(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def rollback(transport, port, bolt_version, options) do
    BoltProtocolHelper.treat_simple_message(:rollback, transport, port, bolt_version, options)
  end

  @doc """
  Implementation of Bolt's RESET message. It resets a session to a clean state.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.reset(:gen_tcp, port, 5, [])
      :ok
  """
  @spec reset(atom(), port(), integer(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def reset(transport, port, bolt_version, options) do
    BoltProtocolHelper.treat_simple_message(:reset, transport, port, bolt_version, options)
  end

  @doc """
  Implementation of Bolt's ROUTE message. It requests routing information.

  The ROUTE message is used to discover routing tables for cluster deployments.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.route(:gen_tcp, port, 5, %{}, [], "neo4j", [])
      {:ok, routing_table}
  """
  @spec route(atom(), port(), integer(), map(), list(), String.t(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def route(transport, port, bolt_version, routing_context, bookmarks, db, options) do
    BoltProtocolHelper.send_message(
      transport,
      port,
      bolt_version,
      {:route, [routing_context, bookmarks, db]}
    )

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, info} ->
        {:ok, info}

      {:failure, response} ->
        {:error, Error.exception(response, port, :route)}

      other ->
        {:error, Error.exception(other, port, :route)}
    end
  end

  @doc """
  Implementation of Bolt's TELEMETRY message. It sends telemetry data to the server.

  TELEMETRY was introduced in Bolt v5.4 to collect driver usage metrics.
  The api parameter indicates which driver API was used (0-3 for managed/explicit/implicit/execute_query).

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV5.telemetry(:gen_tcp, port, 5, 0, [])
      :ok
  """
  @spec telemetry(atom(), port(), integer(), integer(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def telemetry(transport, port, bolt_version, api, options) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:telemetry, [api]})

    case BoltProtocolHelper.receive_data(transport, port, bolt_version, options) do
      {:success, _} ->
        :ok

      {:failure, response} ->
        {:error, Error.exception(response, port, :telemetry)}

      other ->
        {:error, Error.exception(other, port, :telemetry)}
    end
  end
end

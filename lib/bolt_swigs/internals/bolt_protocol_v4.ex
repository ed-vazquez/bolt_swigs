defmodule Bolt.Swigs.Internals.BoltProtocolV4 do
  @moduledoc """
  Implementation of Bolt Protocol version 4.x

  Bolt Protocol v4 introduces:
  - PULL and DISCARD messages replace PULL_ALL and DISCARD_ALL with structured fields
  - Database selection support in BEGIN and RUN messages
  - Query identification (qid) for managing multiple result streams in transactions
  - Streaming control with configurable batch sizes (n parameter)
  """

  alias Bolt.Swigs.Internals.BoltProtocolHelper
  alias Bolt.Swigs.Internals.Error

  @doc """
  Implementation of Bolt's HELLO for v4. It initialises the connection with authentication.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV4.hello(:gen_tcp, port, 4, {"username", "password"}, [])
      {:ok, info}
  """
  @spec hello(atom(), port(), integer(), tuple(), Keyword.t()) ::
          {:ok, any()} | {:error, Bolt.Swigs.Internals.Error.t()}
  def hello(transport, port, bolt_version, auth, options \\ [recv_timeout: 15_000]) do
    BoltProtocolHelper.send_message(transport, port, bolt_version, {:hello, [auth]})

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
  Implementation of Bolt's GOODBYE. It closes the connection.

  ## Examples

      iex> Bolt.Swigs.Internals.BoltProtocolV4.goodbye(:gen_tcp, port, 4)
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

  In Bolt v4, RUN supports database selection via metadata.

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Example

      iex> BoltProtocolV4.run(:gen_tcp, port, 4, "RETURN $num AS num", %{num: 5}, %{}, [])
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

  In Bolt v4, PULL replaces PULL_ALL and supports:
  - `n`: number of records to fetch (-1 for all)
  - `qid`: query identification for explicit transactions

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      # Pull all records
      iex> BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: -1}, [])
      {:ok, [...]}

      # Pull 100 records
      iex> BoltProtocolV4.pull(:gen_tcp, port, 4, %{n: 100}, [])
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

  In Bolt v4, DISCARD replaces DISCARD_ALL and supports:
  - `n`: number of records to discard (-1 for all)
  - `qid`: query identification for explicit transactions

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.

  ## Examples

      # Discard all records
      iex> BoltProtocolV4.discard(:gen_tcp, port, 4, %{n: -1}, [])
      :ok

      # Discard 100 records
      iex> BoltProtocolV4.discard(:gen_tcp, port, 4, %{n: 100}, [])
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
  Runs a statement and returns all records (RUN + PULL).

  ## Options

  See "Shared options" in `Bolt.Swigs.Internals.BoltProtocolHelper` documentation.
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
          [Bolt.Swigs.Internals.PackStream.Message.decoded()]
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

  In Bolt v4, BEGIN supports database selection via metadata.

  ## Example

      iex> BoltProtocolV4.begin(:gen_tcp, port, 4, %{}, [])
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

  ## Example

      iex> BoltProtocolV4.commit(:gen_tcp, port, 4, [])
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

  ## Example

      iex> BoltProtocolV4.rollback(:gen_tcp, port, 4, [])
      :ok
  """
  @spec rollback(atom(), port(), integer(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def rollback(transport, port, bolt_version, options) do
    BoltProtocolHelper.treat_simple_message(:rollback, transport, port, bolt_version, options)
  end

  @doc """
  Implementation of Bolt's RESET message. It resets a session to a clean state.

  ## Example

      iex> BoltProtocolV4.reset(:gen_tcp, port, 4, [])
      :ok
  """
  @spec reset(atom(), port(), integer(), Keyword.t()) ::
          :ok | {:error, Bolt.Swigs.Internals.Error.t()}
  def reset(transport, port, bolt_version, options) do
    BoltProtocolHelper.treat_simple_message(:reset, transport, port, bolt_version, options)
  end
end

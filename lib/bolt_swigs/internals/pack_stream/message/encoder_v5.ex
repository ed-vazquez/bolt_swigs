defmodule Bolt.Swigs.Internals.PackStream.Message.EncoderV5 do
  @moduledoc false
  use Bolt.Swigs.Internals.PackStream.Message.Signatures
  alias Bolt.Swigs.Internals.PackStream.Message.Encoder

  @valid_signatures [
    @begin_signature,
    @commit_signature,
    @discard_signature,
    @goodbye_signature,
    @hello_signature,
    @logoff_signature,
    @logon_signature,
    @pull_signature,
    @reset_signature,
    @rollback_signature,
    @route_signature,
    @run_signature,
    @telemetry_signature
  ]

  @doc """
  Return the valid signatures for Bolt V5
  """
  @spec valid_signatures() :: [integer()]
  def valid_signatures() do
    @valid_signatures
  end

  @doc """
  Encode messages for Bolt V5
  """
  @spec encode({Bolt.Swigs.Internals.PackStream.Message.out_signature(), list()}, integer()) ::
          Bolt.Swigs.Internals.PackStream.Message.encoded()
          | {:error, :not_implemented}
          | {:error, :invalid_message}
  def encode(data, bolt_version) do
    Encoder.encode(data, bolt_version)
  end
end

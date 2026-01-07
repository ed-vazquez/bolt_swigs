defmodule Bolt.Swigs.Internals.PackStream.Message.EncoderV1 do
  @moduledoc false
  use Bolt.Swigs.Internals.PackStream.Message.Signatures
  alias Bolt.Swigs.Internals.PackStream.Message.Encoder

  @doc """
  Encode INIT message without auth token
  """
  @spec encode({Bolt.Swigs.Internals.PackStream.Message.out_signature(), list()}, integer()) ::
          Bolt.Swigs.Internals.PackStream.Message.encoded() | {:error, :not_implemented}
  def encode(data, bolt_version) do
    Encoder.encode(data, bolt_version)
  end
end

alias Bolt.Swigs.Internals.PackStream
alias Bolt.Swigs.Internals.PackStream.EncoderHelper

defprotocol Bolt.Swigs.Internals.PackStream.Encoder do
  @moduledoc false

  # Encodes an item to its binary PackStream Representation
  #
  # Implementation exists for following types:
  #   - Integer
  #   - Float
  #   - List
  #   - Map
  #   - Struct (defined in the Bolt protocol)
  @fallback_to_any true

  @doc """
  Encode entity into its Bolt binary represenation depending of the used bolt version
  """

  @spec encode(any(), integer()) :: binary()
  def encode(entity, bolt_version)
end

defimpl PackStream.Encoder, for: Atom do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:atom, data, bolt_version)
end

defimpl PackStream.Encoder, for: BitString do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:string, data, bolt_version)
end

defimpl PackStream.Encoder, for: Integer do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:integer, data, bolt_version)
end

defimpl PackStream.Encoder, for: Float do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:float, data, bolt_version)
end

defimpl PackStream.Encoder, for: List do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:list, data, bolt_version)
end

defimpl PackStream.Encoder, for: Map do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:map, data, bolt_version)
end

defimpl PackStream.Encoder, for: Time do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:local_time, data, bolt_version)
end

defimpl PackStream.Encoder, for: Bolt.Swigs.Types.TimeWithTZOffset do
  def encode(data, bolt_version) do
    EncoderHelper.call_encode(:time_with_tz, data, bolt_version)
  end
end

defimpl PackStream.Encoder, for: Date do
  def encode(data, bolt_version), do: EncoderHelper.call_encode(:date, data, bolt_version)
end

defimpl PackStream.Encoder, for: NaiveDateTime do
  def encode(data, bolt_version) do
    EncoderHelper.call_encode(:local_datetime, data, bolt_version)
  end
end

defimpl PackStream.Encoder, for: DateTime do
  def encode(data, version) do
    EncoderHelper.call_encode(:datetime_with_tz_id, data, version)
  end
end

defimpl PackStream.Encoder, for: Bolt.Swigs.Types.DateTimeWithTZOffset do
  def encode(data, version) do
    EncoderHelper.call_encode(:datetime_with_tz_offset, data, version)
  end
end

defimpl PackStream.Encoder, for: Bolt.Swigs.Types.Duration do
  def encode(data, version), do: EncoderHelper.call_encode(:duration, data, version)
end

defimpl PackStream.Encoder, for: Bolt.Swigs.Types.Point do
  def encode(data, version), do: EncoderHelper.call_encode(:point, data, version)
end

defimpl PackStream.Encoder, for: Any do
  @spec encode({integer(), list()} | %{:__struct__ => String.t()}, integer()) ::
          Bolt.Swigs.Internals.PackStream.value() | <<_::16, _::_*8>>
  def encode({signature, data}, bolt_version) when is_list(data) do
    valid_signatures =
      PackStream.Message.Encoder.valid_signatures(bolt_version) ++
        Bolt.Swigs.Internals.PackStream.MarkersHelper.valid_signatures()

    if signature in valid_signatures do
      EncoderHelper.call_encode(:struct, {signature, data}, bolt_version)
    else
      raise Bolt.Swigs.Internals.PackStreamError,
        message: "Unable to encode",
        data: data,
        bolt_version: bolt_version
    end
  end

  # Elixir structs just need to be convertedd to map befoare being encoded
  def encode(%{__struct__: _} = data, bolt_version) do
    map = Map.from_struct(data)
    PackStream.Encoder.encode(map, bolt_version)
  end

  def encode(data, bolt_version) do
    raise Bolt.Swigs.Internals.PackStreamError,
      message: "Unable to encode",
      data: data,
      bolt_version: bolt_version
  end
end

defmodule Bolt.Swigs.Internals.PackStream.Message.Signatures do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      # Message OUT
      @ack_failure_signature 0x0E
      @begin_signature 0x11
      @commit_signature 0x12
      @discard_all_signature 0x2F
      @discard_signature 0x2F
      @goodbye_signature 0x02
      @hello_signature 0x01
      @init_signature 0x01
      @logoff_signature 0x6B
      @logon_signature 0x6A
      @pull_all_signature 0x3F
      @pull_signature 0x3F
      @reset_signature 0x0F
      @rollback_signature 0x13
      @route_signature 0x66
      @run_signature 0x10
      @telemetry_signature 0x54

      # Message IN
      @success_signature 0x70
      @failure_signature 0x7F
      @record_signature 0x71
      @ignored_signature 0x7E
    end
  end
end

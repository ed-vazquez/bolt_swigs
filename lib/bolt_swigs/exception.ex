defmodule Bolt.Swigs.Exception do
  @moduledoc """
  This module defines a `Bolt.Swigs.Exception` structure containing two fields:

  * `code` - the error code
  * `message` - the error details
  """
  @type t :: %Bolt.Swigs.Exception{}

  defexception [:code, :message]
end

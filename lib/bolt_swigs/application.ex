defmodule Bolt.Swigs.Application do
  @moduledoc false

  use Application

  alias Bolt.Swigs

  def start(_, start_args) do
    Swigs.start_link(start_args)
  end

  def stop(_state) do
    :ok
  end
end

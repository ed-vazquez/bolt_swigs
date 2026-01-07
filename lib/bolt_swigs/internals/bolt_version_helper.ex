defmodule Bolt.Swigs.Internals.BoltVersionHelper do
  @moduledoc false
  @available_bolt_versions [1, 2, 3, 4, 5]

  @doc """
  List bolt versions.
  Only bolt version that have specific encoding functions are listed.

  """
  @spec available_versions() :: [integer()]
  def available_versions(), do: @available_bolt_versions

  @doc """
  Retrieve previous valid version.
  Return nil if there is no previous version.

  ## Example

      iex> Bolt.Swigs.Internals.BoltVersionHelper.previous(2)
      1
      iex> Bolt.Swigs.Internals.BoltVersionHelper.previous(1)
      nil
      iex> Bolt.Swigs.Internals.BoltVersionHelper.previous(15)
      3
  """
  @spec previous(integer()) :: nil | integer()
  def previous(version) do
    @available_bolt_versions
    |> Enum.take_while(&(&1 < version))
    |> List.last()
  end

  @doc """
  Return the last available bolt version.

  ## Example:

      iex> Bolt.Swigs.Internals.BoltVersionHelper.last()
      5
  """
  def last() do
    List.last(@available_bolt_versions)
  end
end

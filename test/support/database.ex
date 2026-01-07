defmodule Bolt.Swigs.Test.Support.Database do
  def clear(conn) do
    Bolt.Swigs.query!(conn, "MATCH (n) DETACH DELETE n")
  end
end

defmodule Bolt.Swigs.ConnCase do
  use ExUnit.CaseTemplate

  setup_all do
    Bolt.Swigs.start_link(Application.get_env(:bolt_swigs, Bolt))
    conn = Bolt.Swigs.conn()

    on_exit(fn ->
      Bolt.Swigs.Test.Support.Database.clear(conn)
    end)

    {:ok, conn: conn}
  end
end

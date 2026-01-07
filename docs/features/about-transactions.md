# About transactions

Transaction management in Neo4j 3.5+ differs from what it was in prior versions.
The cypher keyword `BEGIN`, `COMMIT` and `ROLLBACK` are no longer available.

In order to have a query that runs fine in all versions, you should use the following pattern:

```elixir
# Commit is performed automatically if everythings went fine
conn = Bolt.Swigs.conn()
Bolt.Swigs.transaction(conn, fn conn ->
  result = Bolt.Swigs.query!(conn, "CREATE (m:Movie {title: "Matrix"}) RETURN m")
end)

# Rollback is performed automatically in case of error
Bolt.Swigs.transaction(conn, fn conn ->
  result =Bolt.Swigs.query!(conn, "Invalid query")
end)

# Rollback can stil be forced
Bolt.Swigs.transaction(conn, fn conn ->
  result = Bolt.Swigs.query!(conn, "CREATE (m:Movie {title: "Matrix"}) RETURN m")
  Bolt.Swigs.rollback(conn, :dont_save)
end)
```

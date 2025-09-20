# frozen_string_literal: true

RSpec.describe "Patching ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#new_client" do
  it "raises ActiveRecord::NoDatabaseError for a missing database" do
    conn_params = { dbname: "non_existent_db" }

    expect do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new_client(conn_params)
    end.to raise_error(ActiveRecord::NoDatabaseError, /non_existent_db/)
  end

  it "raises ActiveRecord::DatabaseConnectionError when error message contains the `host` connection params" do
    conn_params = { host: "some-host", user: "test_user" }

    PG.expects(:connect).raises(
      ::PG::Error.new(
        "connection to server at \"some-host.name\" (::1), port 6432 failed: timeout expired after 11.30376464s",
      ),
    )

    expect do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new_client(conn_params)
    end.to raise_error(
      ActiveRecord::DatabaseConnectionError,
      /connection to server at "some-host.name"/,
    )
  end

  it "raises ActiveRecord::DatabaseConnectionError when error message contains the `user` connection params" do
    conn_params = { user: "test_user" }

    PG.expects(:connect).raises(
      ::PG::Error.new("FATAL:  password authentication failed for user \"test_user\""),
    )

    expect do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new_client(conn_params)
    end.to raise_error(
      ActiveRecord::DatabaseConnectionError,
      /password authentication failed for user "test_user"/,
    )
  end
end

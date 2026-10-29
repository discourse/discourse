# frozen_string_literal: true

RSpec.describe Migrations::Database::Drivers::Sqlite do
  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, "driver.db")
      example.run
    end
  end

  let(:driver) { described_class.new(path: @path, reopenable: true) }
  let(:read_value) do
    ->(connection) { connection.with { |native| native.query_single_splat("SELECT 42") } }
  end
  let(:native_closed) { ->(native) { native.closed? } }

  it_behaves_like "a managed database driver"

  it "closes the native handle before the split and preserves writes from fresh worker connections" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    native =
      connection.with do |handle|
        handle.execute("CREATE TABLE records (id INTEGER)")
        handle
      end
    expect(
      in_migration_worker do
        was_closed = native.closed?
        worker = Migrations::Database::Connection.new(path: @path)
        begin
          worker.execute("INSERT INTO records VALUES (1)")
        ensure
          worker.close
        end
        was_closed
      end,
    ).to be(true)
    expect(
      connection.with { |handle| handle.query_single_splat("SELECT COUNT(*) FROM records") },
    ).to eq(1)
    expect(connection.with { |handle| handle.query_single_splat("PRAGMA integrity_check") }).to eq(
      "ok",
    )
  ensure
    connection&.close
  end
end

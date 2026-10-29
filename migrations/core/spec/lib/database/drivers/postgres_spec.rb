# frozen_string_literal: true

RSpec.describe Migrations::Database::Drivers::Postgres, :postgres do
  let(:settings) { { dbname: ENV.fetch("MIGRATIONS_POSTGRES_DB") } }
  let(:driver) { described_class.new(settings) }
  let(:read_value) do
    ->(connection) { connection.with { |native| native.exec("SELECT 42").getvalue(0, 0) } }
  end
  let(:native_closed) { ->(native) { native.finished? } }

  it_behaves_like "a managed database driver"

  it "keeps the original parent session alive when construction overlaps a worker fork" do
    connected, release = Queue.new, Queue.new
    allow(PG::Connection).to receive(:new).and_wrap_original do |original, *args|
      native = original.call(*args)
      connected << true
      release.pop
      native
    end
    opener = Thread.new { Migrations::Database::ManagedConnection.open(driver) }
    connected.pop
    forker =
      Thread.new do
        in_migration_worker do
          3.times { GC.start(full_mark: true, immediate_sweep: true) }
          :collected
        end
      end
    wait_until_stopped(forker)
    expect(forker).to be_alive
    release << true
    connection = opener.value
    backend_pid = connection.with { |native| native.backend_pid }
    expect(forker.value).to eq(:collected)
    expect(
      connection.with { |native| native.exec("SELECT pg_backend_pid()").getvalue(0, 0) },
    ).to eq(backend_pid)
  ensure
    release << true
    opener&.join
    forker&.join
    connection&.close
  end

  it "keeps a parent's suspended stream usable across child garbage collection" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    stream =
      Migrations::Database::PostgresStream.new(
        connection,
        "SELECT generate_series(1, 10)",
        [],
        arrays: true,
      )
    expect(stream.next).to eq(1)
    expect(
      in_migration_worker do
        GC.start
        :collected
      end,
    ).to eq(:collected)
    expect(stream.to_a).to eq((2..10).to_a)
    expect(read_value.call(connection)).to eq(42)
  ensure
    stream&.close
    connection&.close
  end

  it "releases and drains a stream after partial iteration, explicit close, or an exception" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    stream_class = Migrations::Database::PostgresStream
    sql = "SELECT generate_series(1, 10)"
    stream = stream_class.new(connection, sql, [], arrays: true)
    expect { connection.close }.to raise_error(Migrations::Database::ManagedConnection::BusyError)
    stream.each { break }
    expect(read_value.call(connection)).to eq(42)
    stream = stream_class.new(connection, sql, [], arrays: true)
    stream.next
    stream.close
    expect(read_value.call(connection)).to eq(42)
    stream = stream_class.new(connection, sql, [], arrays: true)
    expect { stream.each { raise "consumer failed" } }.to raise_error("consumer failed")
    expect(read_value.call(connection)).to eq(42)
  ensure
    stream&.close
    connection&.close
  end

  it "yields directly in the caller's fiber while reserving the query's connection" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    stream = Migrations::Database::PostgresStream.new(connection, "SELECT 42", [])
    caller = Fiber.current
    stream.each do |row|
      expect(Fiber.current).to equal(caller)
      expect(row.values).to eq([42])
      expect { read_value.call(connection) }.to raise_error(
        Migrations::Database::ManagedConnection::BusyError,
      )
    end
    expect(read_value.call(connection)).to eq(42)
  ensure
    stream&.close
    connection&.close
  end

  it "fails the worker immediately if socket redirection fails" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    socket = connection.with(&:socket_io)
    allow(socket).to receive(:reopen).and_raise(Errno::EMFILE)
    _, status = Process.waitpid2(Migrations::ForkManager.fork { Process.exit!(0) })
    expect(status.exitstatus).to eq(1)
    expect(read_value.call(connection)).to eq(42)
  ensure
    connection&.close
  end
end

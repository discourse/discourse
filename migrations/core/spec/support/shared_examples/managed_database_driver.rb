# frozen_string_literal: true

RSpec.shared_examples "a managed database driver" do
  it "preserves the parent's connection and invalidates the inherited connection" do
    connection = Migrations::Database::ManagedConnection.open(driver)
    expect(read_value.call(connection)).to eq(42)
    expect(
      in_migration_worker do
        GC.start(full_mark: true, immediate_sweep: true)
        begin
          read_value.call(connection)
        rescue Migrations::Database::ManagedConnection::DiscardedError
          :discarded
        end
      end,
    ).to eq(:discarded)
    expect(read_value.call(connection)).to eq(42)
  ensure
    connection&.close
  end

  it "cleans up failed configuration before allowing another fork" do
    native = nil
    baseline = Migrations::Database::Lifecycle.connection_count
    allow(driver).to receive(:configure) do |handle|
      native = handle
      raise "configuration failed"
    end
    expect { Migrations::Database::ManagedConnection.open(driver) }.to raise_error(
      "configuration failed",
    )
    expect(native_closed.call(native)).to be(true)
    expect(Migrations::Database::Lifecycle.connection_count).to eq(baseline)
    expect(in_migration_worker { :ok }).to eq(:ok)
  end
end

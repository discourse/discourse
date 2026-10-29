# frozen_string_literal: true

RSpec.describe Migrations::Database::ManagedConnection do
  let(:driver) { MigrationsLifecycleTestDriver.new(:discard) }
  let(:lifecycle) { Migrations::Database::Lifecycle }
  let(:manager) { Migrations::ForkManager }

  after do
    driver.close_error = nil
    @connection&.close
  end

  it "closes a partially configured connection and unregisters it" do
    baseline = lifecycle.connection_count
    driver.configure_error = RuntimeError.new("configuration failed")
    expect { described_class.open(driver) }.to raise_error("configuration failed")
    expect(driver.handles.last).to be_closed
    expect(lifecycle.connection_count).to eq(baseline)
  end

  it "unregisters a failed constructor" do
    baseline = lifecycle.connection_count
    driver.open_error = RuntimeError.new("open failed")
    expect { described_class.open(driver) }.to raise_error("open failed")
    expect(lifecycle.connection_count).to eq(baseline)
  end

  it "prohibits forks when the driver has no policy" do
    driver.singleton_class.undef_method(:fork_policy)
    @connection = described_class.open(driver)
    expect { manager.fork {} }.to raise_error(lifecycle::UnsafeForkError, /no approved fork policy/)
    expect(@connection.with(&:closed?)).to be(false)
  end

  it "retains protection if close fails" do
    @connection = described_class.open(driver)
    driver.close_error = RuntimeError.new("close failed")
    baseline = lifecycle.connection_count
    expect { @connection.close }.to raise_error("close failed")
    expect(lifecycle.connection_count).to eq(baseline)
    expect(in_migration_worker { @connection.closed? }).to be(true)
  end

  it "rejects connection use in a worker while preserving the parent's connection" do
    @connection = described_class.open(driver)
    expect(
      in_migration_worker do
        @connection.with(&:closed?)
      rescue described_class::DiscardedError
        :discarded
      end,
    ).to eq(:discarded)
    expect(@connection.with(&:closed?)).to be(false)
  end

  it "holds an operation lease across suspended fibers" do
    @connection = described_class.open(driver)
    fiber = Fiber.new { @connection.with { Fiber.yield :reading } }
    expect(fiber.resume).to eq(:reading)
    expect { @connection.close }.to raise_error(described_class::BusyError)
    expect { @connection.with {} }.to raise_error(described_class::BusyError)
    fiber.resume
    expect { @connection.close }.not_to raise_error
  ensure
    fiber.resume if fiber&.alive?
  end

  it "rejects a fork initiated inside a connection operation" do
    @connection = described_class.open(driver)
    expect { @connection.with { manager.fork {} } }.to raise_error(lifecycle::UnsafeForkError)
  end

  it "allows forks while another thread reads a discardable connection" do
    @connection = described_class.open(driver)
    entered, release = Queue.new, Queue.new
    reader =
      Thread.new do
        @connection.with do |native|
          entered << true
          release.pop
          native.closed?
        end
      end
    entered.pop
    expect(in_migration_worker { @connection.closed? }).to be(true)
    release << true
    expect(reader.value).to be(false)
  ensure
    release << true
    reader&.join
  end

  it "keeps close and unregister inside the lifecycle barrier" do
    @connection = described_class.open(driver)
    entered, release = Queue.new, Queue.new
    allow(driver).to receive(:close).and_wrap_original do |original, native|
      entered << true
      release.pop
      original.call(native)
    end
    closer = Thread.new { @connection.close }
    entered.pop
    forker = Thread.new { in_migration_worker { :worker } }
    wait_until_stopped(forker)
    expect(forker).to be_alive
    release << true
    closer.value
    expect(forker.value).to eq(:worker)
  ensure
    release << true
    closer&.join
    forker&.join
  end

  it "prevents a fork until native construction and configuration finish" do
    opened, release = Queue.new, Queue.new
    allow(driver).to receive(:configure) do
      opened << true
      release.pop
    end
    opener = Thread.new { @connection = described_class.open(driver) }
    opened.pop
    forker = Thread.new { in_migration_worker { driver.handles.last.closed? } }
    wait_until_stopped(forker)
    expect(forker).to be_alive
    release << true
    opener.value
    expect(forker.value).to be(true)
  ensure
    release << true
    opener&.join
    forker&.join
  end

  it "blocks new connections throughout a batch and rejects opening one from the batch itself" do
    started, release = Queue.new, Queue.new
    batch =
      Thread.new do
        manager.with_batched_forks do
          started << true
          release.pop
        end
      end
    started.pop
    opener = Thread.new { @connection = described_class.open(driver) }
    wait_until_stopped(opener)
    expect(driver.handles).to be_empty
    release << true
    batch.value
    opener.value
    expect do manager.with_batched_forks { described_class.open(driver) } end.to raise_error(
      lifecycle::UnsafeForkError,
      /inside a fork batch/,
    )
  ensure
    release << true
    batch&.join
    opener&.join
  end

  [false, true].each do |batched|
    it "restores connections after a failed #{batched ? "batched" : "ordinary"} fork" do
      driver.fork_policy = :close_reopen
      @connection = described_class.open(driver)
      allow(Process).to receive(:fork).and_raise(Errno::EAGAIN)
      expect do
        if batched
          manager.with_batched_forks { manager.fork {} }
        else
          manager.fork {}
        end
      end.to raise_error(Errno::EAGAIN)
      expect(driver.handles.first).to be_closed
      expect(@connection.with(&:closed?)).to be(false)
    end
  end

  it "restores earlier resources when preparation of another resource fails" do
    driver.fork_policy = :close_reopen
    @connection = described_class.open(driver)
    other_driver = MigrationsLifecycleTestDriver.new(:close_reopen)
    other = described_class.open(other_driver)
    other_driver.close_error = RuntimeError.new("preparation failed")
    expect { manager.fork {} }.to raise_error("preparation failed")
    expect(@connection.with(&:closed?)).to be(false)
    expect(driver.handles.size).to eq(2)
  ensure
    other_driver.close_error = nil
    other&.close
  end

  it "restores every resource even if another resource cannot reopen" do
    driver.fork_policy = :close_reopen
    @connection = described_class.open(driver)
    other_driver = MigrationsLifecycleTestDriver.new(:close_reopen)
    other = described_class.open(other_driver)
    expect do
      manager.with_batched_forks { other_driver.open_error = RuntimeError.new("reopen failed") }
    end.to raise_error(lifecycle::RecoveryError, /reopen failed/)
    expect(@connection.with(&:closed?)).to be(false)
    expect { other.with {} }.to raise_error(described_class::UnavailableError)
    expect { manager.fork {} }.to raise_error(lifecycle::UnsafeForkError)
  ensure
    other&.close
  end

  it "exits without running the worker when native discard fails" do
    @connection = described_class.open(driver)
    driver.discard_error = IOError.new("redirection failed")
    _, status = Process.waitpid2(manager.fork { Process.exit!(0) })
    expect(status.exitstatus).to eq(1)
    expect(@connection.with(&:closed?)).to be(false)
  end
end

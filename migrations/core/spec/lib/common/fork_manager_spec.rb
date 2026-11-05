# frozen_string_literal: true

RSpec.describe Migrations::ForkManager do
  after { described_class.clear! }

  it "runs child hooks before the worker block" do
    order = []
    described_class.after_fork_child { order << :hook }
    expect(in_migration_worker { order << :worker }).to eq(%i[hook worker])
    expect(order).to eq([])
  end

  it "runs hooks in every worker in a batch" do
    described_class.after_fork_child { Thread.current[:hook_pid] = Process.pid }
    results =
      described_class.with_batched_forks do
        Array.new(2) { in_migration_worker { Thread.current[:hook_pid] == Process.pid } }
      end
    expect(results).to eq([true, true])
  end

  it "reads hooks registered immediately before the process split" do
    ran = false
    allow(Process).to receive(:_fork).and_wrap_original do |original, *args|
      described_class.after_fork_child { ran = true }
      original.call(*args)
    end
    expect(in_migration_worker { ran }).to be(true)
  end

  it "allows hooks to be removed" do
    hook = described_class.after_fork_child { raise "removed hook" }
    described_class.remove_after_fork_child(hook)
    expect(in_migration_worker { :ok }).to eq(:ok)
    expect(described_class.hook_count).to eq(0)
  end

  it "lets child threads create resources and fork again" do
    result =
      in_migration_worker do
        Timeout.timeout(5) do
          Thread
            .new do
              described_class.without_forks { :resource }
              _, status = Process.waitpid2(described_class.fork { Process.exit!(0) })
              status.success?
            end
            .value
        end
      end
    expect(result).to be(true)
  end

  it "exits immediately when a child hook fails, without running worker code or at_exit" do
    reader, writer = IO.pipe
    described_class.after_fork_child do
      at_exit { writer.write("cleanup") }
      raise "unsafe inherited resource"
    end
    pid = described_class.fork { writer.write("worker") }
    writer.close
    _, status = Process.waitpid2(pid)
    expect(status.exitstatus).to eq(1)
    expect(reader.read).to eq("")
  ensure
    reader&.close
    writer&.close unless writer&.closed?
  end

  it "terminates and reaps already started workers when a later fork fails" do
    attempts = 0
    first_pid = nil
    allow(Process).to receive(:fork).and_wrap_original do |original, &block|
      attempts += 1
      raise Errno::EAGAIN if attempts == 2
      original.call(&block)
    end

    expect do
      described_class.with_batched_forks do
        first_pid = described_class.fork { sleep }
        described_class.fork {}
      end
    end.to raise_error(Errno::EAGAIN)
    expect { Process.waitpid(first_pid) }.to raise_error(Errno::ECHILD)
    expect(described_class.without_forks { :released }).to eq(:released)
  end
end

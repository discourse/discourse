# frozen_string_literal: true

RSpec.describe Migrations::ForkManager do
  after { described_class.clear! }

  describe ".after_fork_child" do
    it "runs hooks in the forked process before the fork block" do
      read_io, write_io = IO.pipe
      described_class.after_fork_child { write_io.write("hook:#{Process.pid}") }

      pid = described_class.fork { write_io.write(" block:#{Process.pid}") }
      Process.waitpid(pid)
      write_io.close

      expect(read_io.read).to eq("hook:#{pid} block:#{pid}")
      read_io.close
    end

    it "runs hooks in every fork created by `with_batched_forks`" do
      read_io, write_io = IO.pipe
      described_class.after_fork_child { write_io.write("x") }

      described_class.with_batched_forks { 2.times { Process.waitpid(described_class.fork {}) } }
      write_io.close

      expect(read_io.read).to eq("xx")
      read_io.close
    end

    it "returns the hook so it can be removed again" do
      hook = described_class.after_fork_child { raise "this hook should not run" }
      expect(described_class.hook_count).to eq(1)

      described_class.remove_after_fork_child(hook)
      expect(described_class.hook_count).to eq(0)

      _, status = Process.waitpid2(described_class.fork {})
      expect(status).to be_success
    end
  end

  describe ".remove_after_fork_child" do
    it "stops the removed hook from running while other hooks keep running" do
      read_io, write_io = IO.pipe
      hook = described_class.after_fork_child { write_io.write("removed") }
      described_class.after_fork_child { write_io.write("kept") }

      described_class.remove_after_fork_child(hook)
      expect(described_class.hook_count).to eq(1)

      Process.waitpid(described_class.fork {})
      write_io.close

      expect(read_io.read).to eq("kept")
      read_io.close
    end
  end
end

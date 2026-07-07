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

  describe ".with_batched_forks" do
    it "runs the after-fork parent hooks even when the block raises" do
      ran = false
      described_class.after_fork_parent { ran = true }

      expect { described_class.with_batched_forks { raise "fork exploded" } }.to raise_error(
        "fork exploded",
      )
      expect(ran).to be(true)
    end

    it "keeps the batched state thread-local so a concurrent batch doesn't leak" do
      # Observe the parent-hook decision without a real fork: a batched fork skips
      # the per-fork parent hooks (they run once in `with_batched_forks`), an
      # unbatched one runs them itself. The hook tags itself with the running
      # thread so we can tell whose fork ran it.
      allow(Process).to receive(:fork).and_return(4242)
      ran = Queue.new
      described_class.after_fork_parent { ran << Thread.current[:tag] }

      a_batched = Queue.new
      release_a = Queue.new
      a =
        Thread.new do
          Thread.current[:tag] = :a
          described_class.with_batched_forks do
            a_batched << true
            release_a.pop # stay inside the batch while B forks unbatched
          end
        end
      a_batched.pop

      b_done = Queue.new
      Thread.new do
        Thread.current[:tag] = :b
        described_class.fork {} # not batched: must run the parent hook itself
        b_done << true
      end
      b_done.pop

      # B's unbatched fork ran the parent hook despite A being mid-batch. With a
      # process-global flag, B would have seen A's batched state and skipped it.
      collected = []
      collected << ran.pop until ran.empty?
      expect(collected).to include(:b)

      release_a << true
      a.join
    end
  end
end

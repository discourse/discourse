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

    # A source connection registers its hook, then opens its socket. If another
    # thread forks in between, the child has to run that hook, or the socket it
    # inherits stays open until its exit ends the parent's session too.
    it "runs a hook registered after the fork began but before the process split" do
      read_io, write_io = IO.pipe
      allow(Process).to receive(:_fork).and_wrap_original do |original, *args|
        described_class.after_fork_child { write_io.write("late hook") }
        original.call(*args)
      end

      Process.waitpid(described_class.fork {})
      write_io.close

      expect(read_io.read).to eq("late hook")
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

    it "restores the batched flag when a before-fork hook raises" do
      # A raising before-fork hook must not leave the flag stuck as true on this
      # thread. If it did, a later plain fork would think it is still batched and
      # silently skip its own parent-side hooks.
      allow(Process).to receive(:fork).and_return(4242)
      boom = described_class.before_fork { raise "before-fork exploded" }

      parent_ran = false
      described_class.after_fork_parent { parent_ran = true }

      expect { described_class.with_batched_forks {} }.to raise_error("before-fork exploded")

      described_class.remove_before_fork(boom)
      described_class.fork {}
      expect(parent_ran).to be(true)
    end

    it "delays a concurrent fork until the batch has finished" do
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
      b =
        Thread.new do
          Thread.current[:tag] = :b
          described_class.fork {}
          b_done << true
        end

      sleep 0.05
      expect(b_done).to be_empty

      release_a << true
      a.join
      b_done.pop
      b.join

      collected = []
      collected << ran.pop until ran.empty?
      expect(collected).to eq(%i[a b])
    end
  end

  describe ".synchronize" do
    it "delays a concurrent fork until the block has finished" do
      entered = Queue.new
      release = Queue.new
      holder =
        Thread.new do
          described_class.synchronize do
            entered << true
            release.pop
          end
        end
      entered.pop

      forked = Queue.new
      forker = Thread.new { forked << described_class.fork { exit!(0) } }

      sleep 0.05
      expect(forked).to be_empty

      release << true
      pid = forked.pop
      Process.waitpid(pid)
      holder.join
      forker.join
    end

    it "is reentrant, so forking inside the block works" do
      described_class.synchronize do
        described_class.synchronize do
          pid = described_class.fork { exit!(0) }
          Process.waitpid(pid)
        end
      end
    end

    it "waits until a fork's parent hooks have finished" do
      allow(Process).to receive(:fork).and_return(4242)
      hook_started = Queue.new
      release_hook = Queue.new
      described_class.before_fork do
        hook_started << true
        release_hook.pop
      end

      forker = Thread.new { described_class.fork {} }
      hook_started.pop

      synchronized = Queue.new
      waiter = Thread.new { described_class.synchronize { synchronized << true } }

      sleep 0.05
      expect(synchronized).to be_empty

      release_hook << true
      forker.join
      waiter.join
      expect(synchronized.pop).to be(true)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Migrations::ForkManager do
  after { described_class.clear! }

  describe ".before_fork" do
    it "runs hooks in the parent, in registration order, before each fork" do
      order = []
      described_class.before_fork { order << :first }
      described_class.before_fork { order << :second }

      Process.waitpid(described_class.fork {})

      expect(order).to eq(%i[first second])
    end

    it "returns the hook so it can be removed again" do
      hook = described_class.before_fork { raise "this hook should not run" }
      expect(described_class.hook_count).to eq(1)

      described_class.remove_before_fork(hook)
      expect(described_class.hook_count).to eq(0)

      _, status = Process.waitpid2(described_class.fork {})
      expect(status).to be_success
    end

    it "ignores a missing block" do
      expect(described_class.before_fork).to be_nil
      expect(described_class.hook_count).to eq(0)
    end
  end

  describe ".remove_before_fork" do
    it "stops the removed hook from running while other hooks keep running" do
      ran = []
      hook = described_class.before_fork { ran << :removed }
      described_class.before_fork { ran << :kept }

      described_class.remove_before_fork(hook)
      expect(described_class.hook_count).to eq(1)

      Process.waitpid(described_class.fork {})

      expect(ran).to eq([:kept])
    end
  end

  describe ".after_fork_parent" do
    it "runs hooks in the parent, in registration order, after each fork" do
      order = []
      described_class.after_fork_parent { order << :first }
      described_class.after_fork_parent { order << :second }

      Process.waitpid(described_class.fork {})

      expect(order).to eq(%i[first second])
    end

    it "returns the hook so it can be removed again" do
      hook = described_class.after_fork_parent { raise "this hook should not run" }
      expect(described_class.hook_count).to eq(1)

      described_class.remove_after_fork_parent(hook)
      expect(described_class.hook_count).to eq(0)

      _, status = Process.waitpid2(described_class.fork {})
      expect(status).to be_success
    end

    it "ignores a missing block" do
      expect(described_class.after_fork_parent).to be_nil
      expect(described_class.hook_count).to eq(0)
    end
  end

  describe ".remove_after_fork_parent" do
    it "stops the removed hook from running while other hooks keep running" do
      ran = []
      hook = described_class.after_fork_parent { ran << :removed }
      described_class.after_fork_parent { ran << :kept }

      described_class.remove_after_fork_parent(hook)
      expect(described_class.hook_count).to eq(1)

      Process.waitpid(described_class.fork {})

      expect(ran).to eq([:kept])
    end
  end

  describe ".after_fork_child" do
    it "runs hooks in the forked process, in registration order, before the fork block" do
      read_io, write_io = IO.pipe
      described_class.after_fork_child { write_io.write("first:#{Process.pid}") }
      described_class.after_fork_child { write_io.write(" second:#{Process.pid}") }

      pid = described_class.fork { write_io.write(" block:#{Process.pid}") }
      Process.waitpid(pid)
      write_io.close

      expect(read_io.read).to eq("first:#{pid} second:#{pid} block:#{pid}")
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

    it "ignores a missing block" do
      expect(described_class.after_fork_child).to be_nil
      expect(described_class.hook_count).to eq(0)
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

  describe ".fork" do
    it "runs the fork block in the child and returns its pid" do
      read_io, write_io = IO.pipe

      pid = described_class.fork { write_io.write("child:#{Process.pid}") }
      Process.waitpid(pid)
      write_io.close

      expect(pid).to be_a(Integer)
      expect(read_io.read).to eq("child:#{pid}")
      read_io.close
    end

    it "runs the after-fork-child hooks in the child before the block" do
      read_io, write_io = IO.pipe
      described_class.after_fork_child { write_io.write("hook ") }

      pid = described_class.fork { write_io.write("block") }
      Process.waitpid(pid)
      write_io.close

      expect(read_io.read).to eq("hook block")
      read_io.close
    end

    it "runs the before-fork and after-fork-parent hooks in the parent" do
      before_ran = false
      after_ran = false
      described_class.before_fork { before_ran = true }
      described_class.after_fork_parent { after_ran = true }

      Process.waitpid(described_class.fork {})

      expect(before_ran).to be(true)
      expect(after_ran).to be(true)
    end

    it "still runs the child hooks, but not the parent hooks, per fork while batching" do
      before_runs = 0
      after_runs = 0
      described_class.before_fork { before_runs += 1 }
      described_class.after_fork_parent { after_runs += 1 }

      read_io, write_io = IO.pipe
      described_class.after_fork_child { write_io.write("c") }

      statuses = nil
      described_class.with_batched_forks do
        before_runs = 0
        after_runs = 0

        statuses =
          Array.new(2) do
            _, status = Process.waitpid2(described_class.fork {})
            status
          end

        # The individual forks must not run the parent hooks again.
        expect(before_runs).to eq(0)
        expect(after_runs).to eq(0)
      end
      write_io.close

      expect(statuses).to all(be_success)
      expect(read_io.read).to eq("cc")
      read_io.close
    end
  end

  describe ".hook_count" do
    it "counts the hooks across all three lists" do
      described_class.before_fork {}
      described_class.after_fork_parent {}
      described_class.after_fork_parent {}
      described_class.after_fork_child {}
      described_class.after_fork_child {}
      described_class.after_fork_child {}

      expect(described_class.hook_count).to eq(6)
    end
  end

  describe ".clear!" do
    it "removes the hooks from all three lists" do
      described_class.before_fork {}
      described_class.after_fork_parent {}
      described_class.after_fork_child {}

      described_class.clear!

      expect(described_class.hook_count).to eq(0)
    end
  end

  describe ".with_batched_forks" do
    it "runs the before- and after-fork parent hooks once around the whole batch" do
      before_runs = 0
      after_runs = 0
      described_class.before_fork { before_runs += 1 }
      described_class.after_fork_parent { after_runs += 1 }

      described_class.with_batched_forks do
        expect(before_runs).to eq(1)
        expect(after_runs).to eq(0)

        2.times { Process.waitpid(described_class.fork {}) }

        # The individual forks must not run the parent hooks again.
        expect(before_runs).to eq(1)
        expect(after_runs).to eq(0)
      end

      expect(before_runs).to eq(1)
      expect(after_runs).to eq(1)
    end

    it "restores per-fork parent hooks after the batch" do
      before_runs = 0
      described_class.before_fork { before_runs += 1 }

      described_class.with_batched_forks {}
      expect(before_runs).to eq(1)

      Process.waitpid(described_class.fork {})
      expect(before_runs).to eq(2)
    end

    it "runs the after-fork parent hooks even when the block raises" do
      ran = false
      described_class.after_fork_parent { ran = true }

      expect { described_class.with_batched_forks { raise "fork exploded" } }.to raise_error(
        "fork exploded",
      )
      expect(ran).to be(true)
    end
  end
end

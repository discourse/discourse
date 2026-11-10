# frozen_string_literal: true

require "monitor"

module Migrations
  # The fork hooks for a run. `before_fork` and `after_fork_parent` run around a
  # fork, so a connection can close before it and reopen after. `after_fork_child`
  # runs in the new child, e.g. to drop a connection it inherited.
  #
  # Steps add and remove hooks from several threads at once, so a monitor guards the
  # hook lists. A fork copies the child hooks under that monitor, so the child always
  # runs a consistent list.
  module ForkManager
    # The batching flag is per-thread: a batch belongs to the thread that opened
    # it, so the module stays correct even if callers stop serializing their
    # forks behind a shared mutex (today the coordinators do).
    BATCHED_FORKS_KEY = :migrations_fork_manager_batched_forks
    private_constant :BATCHED_FORKS_KEY

    @before_fork_hooks = []
    @after_fork_parent_hooks = []
    @after_fork_child_hooks = []
    @monitor = Monitor.new

    class << self
      # Excludes concurrent forks while the block runs. A connection must register its
      # after-fork hook and finish connecting as one unit: a fork in between
      # inherits the half-open socket without a usable hook, and the child
      # terminates the parent's session on exit. Reentrant, so nested use and
      # forking from inside a hook can't deadlock.
      def synchronize(&block)
        @monitor.synchronize(&block)
      end

      def with_batched_forks
        @monitor.synchronize do
          previous = Thread.current[BATCHED_FORKS_KEY]

          # Restore the flag no matter what. If a before-fork hook raises, the flag
          # would otherwise stick as true on this thread, and every later plain
          # `fork` on it would silently skip its parent-side hooks.
          begin
            Thread.current[BATCHED_FORKS_KEY] = true
            run_before_fork_hooks

            # Always run the after-fork hooks even if forking raises (e.g.
            # `Errno::EAGAIN`/`ENOMEM` under fork pressure). Otherwise the
            # before-fork hooks' effects — a locked writer mutex, a closed run
            # connection — would never be undone and the run would hang instead of
            # failing the step. If a before-fork hook raises, these after-fork
            # hooks don't run — the batch never started.
            begin
              yield
            ensure
              run_after_fork_parent_hooks
            end
          ensure
            Thread.current[BATCHED_FORKS_KEY] = previous
          end
        end
      end

      def before_fork(&block)
        return unless block
        @monitor.synchronize { @before_fork_hooks << block }
        block
      end

      def remove_before_fork(block)
        @monitor.synchronize { @before_fork_hooks.delete(block) }
      end

      def after_fork_parent(&block)
        return unless block
        @monitor.synchronize { @after_fork_parent_hooks << block }
        block
      end

      def remove_after_fork_parent(block)
        @monitor.synchronize { @after_fork_parent_hooks.delete(block) }
      end

      def after_fork_child(&block)
        return unless block
        @monitor.synchronize { @after_fork_child_hooks << block }
        block
      end

      def remove_after_fork_child(block)
        @monitor.synchronize { @after_fork_child_hooks.delete(block) }
      end

      def fork
        @monitor.synchronize do
          # In a batch the parent-side hooks already ran around the whole batch.
          execute_parent = !Thread.current[BATCHED_FORKS_KEY]

          run_before_fork_hooks if execute_parent

          pid =
            Process.fork do
              @after_fork_child_hooks.dup.each(&:call)
              yield
            end

          run_after_fork_parent_hooks if execute_parent

          pid
        end
      end

      def hook_count
        @monitor.synchronize do
          @before_fork_hooks.size + @after_fork_parent_hooks.size + @after_fork_child_hooks.size
        end
      end

      def clear!
        @monitor.synchronize do
          @before_fork_hooks.clear
          @after_fork_parent_hooks.clear
          @after_fork_child_hooks.clear
        end
      end

      private

      def run_before_fork_hooks
        @before_fork_hooks.each(&:call)
      end

      def run_after_fork_parent_hooks
        @after_fork_parent_hooks.each(&:call)
      end
    end
  end
end

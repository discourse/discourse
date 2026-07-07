# frozen_string_literal: true

module Migrations
  # The fork hooks for a run. `before_fork` and `after_fork_parent` run around a
  # fork, so a connection can close before it and reopen after. `after_fork_child`
  # runs in the new child, e.g. to drop a connection it inherited.
  #
  # Steps add and remove hooks from several threads at once, so a mutex guards the
  # hook lists. A fork copies the child hooks under that mutex, so the child always
  # runs a consistent list.
  module ForkManager
    # `with_batched_forks` and the `fork` calls inside its block run on the same
    # thread, so whether the parent-side hooks run per-fork or once for the whole
    # batch is a thread-local flag. Keeping it off the module avoids a hidden
    # contract: several coordinator threads batch their forks at once, and a
    # process-global flag would be safe only as long as they held a shared mutex
    # around the whole call.
    BATCHED_FORKS_KEY = :migrations_fork_manager_batched_forks
    private_constant :BATCHED_FORKS_KEY

    @before_fork_hooks = []
    @after_fork_parent_hooks = []
    @after_fork_child_hooks = []
    @mutex = Mutex.new

    class << self
      def with_batched_forks
        previous = Thread.current[BATCHED_FORKS_KEY]

        # Restore the flag no matter what. If a before-fork hook raises, the flag
        # would otherwise stick as true on this thread, and every later plain
        # `fork` on it would silently skip its parent-side hooks.
        begin
          Thread.current[BATCHED_FORKS_KEY] = true
          @mutex.synchronize { run_before_fork_hooks }

          # Always run the after-fork hooks even if forking raises (e.g.
          # `Errno::EAGAIN`/`ENOMEM` under fork pressure). Otherwise the
          # before-fork hooks' effects — a locked writer mutex, a closed run
          # connection — would never be undone and the run would hang instead of
          # failing the step. A before-fork hook that raises is handled the same
          # as before: the after-fork hooks do not run for a batch that never
          # started.
          begin
            yield
          ensure
            @mutex.synchronize { run_after_fork_parent_hooks }
          end
        ensure
          Thread.current[BATCHED_FORKS_KEY] = previous
        end
      end

      def before_fork(&block)
        return unless block
        @mutex.synchronize { @before_fork_hooks << block }
        block
      end

      def remove_before_fork(block)
        @mutex.synchronize { @before_fork_hooks.delete(block) }
      end

      def after_fork_parent(&block)
        return unless block
        @mutex.synchronize { @after_fork_parent_hooks << block }
        block
      end

      def remove_after_fork_parent(block)
        @mutex.synchronize { @after_fork_parent_hooks.delete(block) }
      end

      def after_fork_child(&block)
        return unless block
        @mutex.synchronize { @after_fork_child_hooks << block }
        block
      end

      def remove_after_fork_child(block)
        @mutex.synchronize { @after_fork_child_hooks.delete(block) }
      end

      def fork
        # In a batch the parent-side hooks run once around the whole batch (see
        # `with_batched_forks`), so a single fork only runs them when it's on its own.
        execute_parent = !Thread.current[BATCHED_FORKS_KEY]

        # Snapshot the child hooks under the lock for a consistent list, but fork
        # outside it so the child can't inherit the mutex held.
        child_hooks =
          if execute_parent
            @mutex.synchronize do
              run_before_fork_hooks
              @after_fork_child_hooks.dup
            end
          else
            @mutex.synchronize { @after_fork_child_hooks.dup }
          end

        pid =
          Process.fork do
            child_hooks.each(&:call)
            yield
          end

        @mutex.synchronize { run_after_fork_parent_hooks } if execute_parent

        pid
      end

      def hook_count
        @mutex.synchronize do
          @before_fork_hooks.size + @after_fork_parent_hooks.size + @after_fork_child_hooks.size
        end
      end

      def clear!
        @mutex.synchronize do
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

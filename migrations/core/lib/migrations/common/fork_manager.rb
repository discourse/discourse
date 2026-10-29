# frozen_string_literal: true

module Migrations
  # All worker forks pass through the database lifecycle barrier. Non-database
  # resources may additionally invalidate their child-side state with a hook.
  module ForkManager
    BATCHED_FORKS_KEY = :migrations_fork_manager_batched_forks
    private_constant :BATCHED_FORKS_KEY

    @after_fork_child_hooks = []
    @mutex = Mutex.new

    class << self
      def without_forks(&block)
        Database::Lifecycle.synchronize(&block)
      end

      def with_batched_forks
        return yield if Thread.current[BATCHED_FORKS_KEY]

        children = []
        begin
          Database::Lifecycle.with_fork do
            Thread.current[BATCHED_FORKS_KEY] = children
            begin
              yield
            ensure
              Thread.current[BATCHED_FORKS_KEY] = nil
            end
          end
        rescue Exception
          # A partially started batch has no caller to drain its worker pipes.
          # Reap only our unreaped children; their incomplete shards are discarded.
          children.each do |pid|
            unless Process.waitpid(pid, Process::WNOHANG)
              Process.kill("KILL", pid)
              Process.waitpid(pid)
            end
          rescue Errno::ECHILD, Errno::ESRCH
            nil
          end
          raise
        end
      end

      def after_fork_child(&block)
        return unless block
        @mutex.synchronize { @after_fork_child_hooks << block }
        block
      end

      def remove_after_fork_child(block)
        @mutex.synchronize { @after_fork_child_hooks.delete(block) }
      end

      def fork(&block)
        return with_batched_forks { fork(&block) } unless Thread.current[BATCHED_FORKS_KEY]

        pid =
          Process.fork do
            Thread.current[BATCHED_FORKS_KEY] = nil
            begin
              Database::Lifecycle.after_fork_child
              @mutex = Mutex.new
              @after_fork_child_hooks.dup.each(&:call)
            rescue Exception => error
              # Normal exit could finalize the very handle we failed to discard.
              begin
                STDERR.puts("Worker initialization failed: #{error.class}: #{error.message}")
              ensure
                Process.exit!(1)
              end
            end
            block.call
          end
        Thread.current[BATCHED_FORKS_KEY] << pid
        pid
      end

      def hook_count
        @mutex.synchronize { @after_fork_child_hooks.size }
      end

      def clear!
        @mutex.synchronize { @after_fork_child_hooks.clear }
      end
    end
  end
end

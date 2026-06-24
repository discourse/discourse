# frozen_string_literal: true

module Migrations
  module ForkManager
    @before_fork_hooks = []
    @after_fork_parent_hooks = []
    @after_fork_child_hooks = []
    @execute_parent_forks = true

    class << self
      def with_batched_forks
        @execute_parent_forks = false
        run_before_fork_hooks

        yield

        run_after_fork_parent_hooks
        @execute_parent_forks = true
      end

      def before_fork(&block)
        if block
          @before_fork_hooks << block
          block
        end
      end

      def remove_before_fork(block)
        @before_fork_hooks.delete(block)
      end

      def after_fork_parent(&block)
        if block
          @after_fork_parent_hooks << block
          block
        end
      end

      def remove_after_fork_parent(block)
        @after_fork_parent_hooks.delete(block)
      end

      def after_fork_child(&block)
        if block
          @after_fork_child_hooks << block
          block
        end
      end

      def remove_after_fork_child(block)
        @after_fork_child_hooks.delete(block)
      end

      def fork
        run_before_fork_hooks if @execute_parent_forks

        pid =
          Process.fork do
            run_after_fork_child_hooks
            yield
          end

        run_after_fork_parent_hooks if @execute_parent_forks

        pid
      end

      def hook_count
        @before_fork_hooks.size + @after_fork_parent_hooks.size + @after_fork_child_hooks.size
      end

      def clear!
        @before_fork_hooks.clear
        @after_fork_parent_hooks.clear
        @after_fork_child_hooks.clear
      end

      private

      def run_before_fork_hooks
        @before_fork_hooks.each(&:call)
      end

      def run_after_fork_parent_hooks
        @after_fork_parent_hooks.each(&:call)
      end

      def run_after_fork_child_hooks
        @after_fork_child_hooks.each(&:call)
      end
    end
  end
end

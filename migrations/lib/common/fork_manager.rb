# frozen_string_literal: true

module Migrations
  module ForkManager
    @before_fork_hooks = []
    @after_fork_parent_hooks = []
    @after_fork_child_hooks = []
    @execute_parent_forks = true

    class << self
      def batch_forks
        @execute_parent_forks = false
        run_before_fork_hooks

        yield

        run_after_fork_parent_hooks
        @execute_parent_forks = true
      end

      def before_fork(run_once: false, &block)
        if block
          @before_fork_hooks << { run_once:, block: }
          block
        end
      end

      def remove_before_fork_hook(block)
        @before_fork_hooks.delete_if { |hook| hook[:block] == block }
      end

      def after_fork_parent(run_once: false, &block)
        if block
          @after_fork_parent_hooks << { run_once:, block: }
          block
        end
      end

      def remove_after_fork_parent_hook(block)
        @after_fork_parent_hooks.delete_if { |hook| hook[:block] == block }
      end

      def after_fork_child(&block)
        if block
          @after_fork_child_hooks << { run_once: true, block: }
          block
        end
      end

      def remove_after_fork_child_hook(block)
        @after_fork_child_hooks.delete_if { |hook| hook[:block] == block }
      end

      def fork
        run_before_fork_hooks if @execute_parent_forks

        pid =
          Process.fork do
            run_after_fork_child_hooks
            yield
          end

        @after_fork_child_hooks.clear

        run_after_fork_parent_hooks if @execute_parent_forks

        pid
      end

      def size
        @before_fork_hooks.size + @after_fork_parent_hooks.size + @after_fork_child_hooks.size
      end

      def clear!
        @before_fork_hooks.clear
        @after_fork_parent_hooks.clear
        @after_fork_child_hooks.clear
      end

      private

      def run_before_fork_hooks
        run_hooks(@before_fork_hooks)
      end

      def run_after_fork_parent_hooks
        run_hooks(@after_fork_parent_hooks)
        cleanup_run_once_hooks(@after_fork_child_hooks)
      end

      def run_after_fork_child_hooks
        run_hooks(@after_fork_child_hooks)
      end

      def run_hooks(hooks)
        hooks.each { |hook| hook[:block].call }
        cleanup_run_once_hooks(hooks)
      end

      def cleanup_run_once_hooks(hooks)
        hooks.delete_if { |hook| hook[:run_once] }
      end
    end
  end
end

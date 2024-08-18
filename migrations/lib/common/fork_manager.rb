# frozen_string_literal: true

module Migrations
  class ForkManager
    include Singleton

    def initialize
      @before_fork_hooks = []
      @after_fork_hooks = []
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

    def after_fork(run_once: false, &block)
      if block
        @after_fork_hooks << { run_once:, block: }
        block
      end
    end

    def remove_after_fork_hook(block)
      @after_fork_hooks.delete_if { |hook| hook[:block] == block }
    end

    def fork
      run_before_fork_hooks

      pid =
        Process.fork do
          run_after_fork_hooks
          yield
        end

      cleanup_run_once_hooks(@after_fork_hooks)

      pid
    end

    private

    def run_before_fork_hooks
      run_hooks(@before_fork_hooks)
    end

    def run_after_fork_hooks
      run_hooks(@after_fork_hooks)
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

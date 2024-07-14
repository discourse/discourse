# frozen_string_literal: true

module Migrations
  class ForkManager
    def initialize
      @before_fork_hooks = []
      @after_fork_hooks = []
      @warmed_up = false
    end

    def before_fork(&block)
      @before_fork_hooks << block if block
    end

    def run_before_fork_hooks
      @before_fork_hooks.each(&:call)
    end

    def after_fork(&block)
      @after_fork_hooks << block if block
    end

    def run_after_fork_hooks
      @after_fork_hooks.each(&:call)
    end

    def fork_process
      run_before_fork_hooks

      if !@warmed_up
        @warmed_up = true
        Process.warmup
      end

      Process.fork do
        run_after_fork_hooks
        yield
      end
    end
  end
end

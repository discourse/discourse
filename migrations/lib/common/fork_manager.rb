# frozen_string_literal: true

module Migrations
  class ForkManager
    include Singleton

    def initialize
      @before_fork_hooks = []
      @after_fork_hooks = []
    end

    def before_fork(&block)
      if block
        @before_fork_hooks << block
        block
      end
    end

    def remove_before_fork_hook(block)
      @before_fork_hooks.delete(block)
    end

    def after_fork(&block)
      if block
        @after_fork_hooks << block
        block
      end
    end

    def remove_after_fork_hook(block)
      @after_fork_hooks.delete(block)
    end

    def fork
      run_before_fork_hooks

      Process.fork do
        run_after_fork_hooks
        yield
      end
    end

    private

    def run_before_fork_hooks
      @before_fork_hooks.each(&:call)
    end

    def run_after_fork_hooks
      @after_fork_hooks.each(&:call)
    end
  end
end

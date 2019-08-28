# frozen_string_literal: true

# This is the 'actually concurrent' counterpart to
# Concurrency::Scenario::Execution from spec/support/concurrency.rb
module Concurrency
  class ThreadedExecution
    def new_mutex
      Mutex.new
    end

    def sleep(delay)
      super(delay)
      nil
    end

    def spawn(&blk)
      Thread.new(&blk)
      nil
    end
  end
end

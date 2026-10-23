# frozen_string_literal: true

module ThreadHelpers
  # Waits for state that another thread is about to reach. Raises instead of
  # hanging when that state never comes.
  def wait_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "condition not reached within #{timeout}s"
      end
      Thread.pass
    end
  end
end

RSpec.configure { |config| config.include ThreadHelpers }

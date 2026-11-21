# frozen_string_literal: true

class MigrationsLifecycleTestDriver
  attr_accessor :fork_policy,
                :configure_error,
                :close_error,
                :open_error,
                :fork_check_error,
                :detach_error
  attr_reader :handles

  def initialize(policy = :forbid_fork)
    @fork_policy = policy
    @handles = []
  end

  def open
    raise @open_error if @open_error
    File.open(IO::NULL, "r+").tap { |handle| @handles << handle }
  end

  def configure(handle)
    raise @configure_error if @configure_error
  end

  def check_before_fork!(handle)
    raise @fork_check_error if @fork_check_error
  end

  def close(handle)
    raise @close_error if @close_error
    handle.close
  end

  def detach(handle)
    raise @detach_error if @detach_error
    handle.close
  end
end

# frozen_string_literal: true

class MigrationsLifecycleTestDriver
  attr_accessor :fork_policy,
                :configure_error,
                :close_error,
                :open_error,
                :validate_error,
                :discard_error
  attr_reader :handles

  def initialize(policy = :forbid)
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

  def validate_fork!(handle)
    raise @validate_error if @validate_error
  end

  def close(handle)
    raise @close_error if @close_error
    handle.close
  end

  def discard(handle)
    raise @discard_error if @discard_error
    handle.close
  end
end

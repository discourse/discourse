# frozen_string_literal: true

module PitchforkReforking
  def self.parse_schedule(value)
    entries = value.split(",", -1).map(&:strip)
    valid =
      entries.any? &&
        entries.each_with_index.all? do |entry, index|
          (entry == "false" && index > 0 && index == entries.length - 1) ||
            (entry.match?(/\A[0-9]+\z/) && entry.to_i.between?(1, 2_147_483_647))
        end

    unless valid
      raise ArgumentError,
            "APP_SERVER_REFORK_AFTER must contain positive request counts separated by commas, optionally ending with false"
    end

    entries.map { |entry| entry == "false" ? false : entry.to_i }
  end

  THREAD_POOL_IDLE_TIMEOUT_SECONDS = 5

  class << self
    attr_accessor :worker, :discard_mold
  end

  def self.wait_for_idle_thread_pools(timeout: THREAD_POOL_IDLE_TIMEOUT_SECONDS)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until Scheduler::ThreadPool.idle?
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    true
  end

  def self.detach_message_bus_clients
    ObjectSpace.each_object(MessageBus::Client) do |client|
      next unless socket = client.io

      unless socket.closed?
        socket.reopen(File::NULL)
        socket.close
      end
      client.io = nil
    end
  end

  # Pitchfork forks on the main thread between requests, so only background
  # threads can be part-way through work that a fork would leave half done in
  # the child (a V8 call, a native lock). They wrap such work in this.
  def self.prevent_fork(&block)
    if defined?(Pitchfork) && Thread.current != Thread.main
      Pitchfork.prevent_fork(&block)
    else
      yield
    end
  end
end

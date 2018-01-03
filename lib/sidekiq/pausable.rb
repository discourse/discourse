require 'thread'

class SidekiqPauser
  def initialize
    @mutex = Mutex.new
  end

  def pause!
    redis.setex paused_key, 60, "paused"
    @mutex.synchronize do
      @extend_lease_thread ||= extend_lease_thread
      sleep 0.001 while !paused?
    end

    true
  end

  def paused?
    !!redis.get(paused_key)
  end

  def unpause!
    @mutex.synchronize do
      @extend_lease_thread = nil
    end

    redis.del(paused_key)
    true
  end

  private

  def extend_lease_thread
    Thread.new do
      while true do
        break unless @mutex.synchronize { @extend_lease_thread }
        redis.expire paused_key, 60
        sleep 30
      end
    end
  end

  def redis
    $redis.without_namespace
  end

  def paused_key
    "sidekiq_is_paused_v2"
  end

end

module Sidekiq
  @pauser = SidekiqPauser.new
  def self.pause!
    @pauser.pause!
  end

  def self.paused?
    @pauser.paused?
  end

  def self.unpause!
    @pauser.unpause!
  end
end

# server middleware that will reschedule work whenever Sidekiq is paused
class Sidekiq::Pausable

  def initialize(delay = 5.seconds)
    @delay = delay
  end

  def call(worker, msg, queue)
    if Sidekiq.paused?
      worker.class.perform_in(@delay, *msg['args'])
    else
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      DiscourseEvent.trigger(:sidekiq_job_ran, worker, msg, queue, duration)
      result
    end
  end

end

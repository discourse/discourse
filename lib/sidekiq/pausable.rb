require 'thread'

class SidekiqPauser
  def initialize
    @mutex = Mutex.new
    @done = ConditionVariable.new
  end

  def pause!
    @mutex.synchronize do
      @paused = true
      @pause_thread ||= start_pause_thread
      sleep 0.001 while !paused?
    end

    true
  end

  def paused?
    Sidekiq.redis { |r| !!r.get(paused_key) }
  end

  def unpause!
    # concurrency is hard, perform signaling from a bg thread
    # otherwise it acts weird
    Thread.new do
      @mutex.synchronize do
        if @pause_thread
          @paused = false
          @done.signal
        end
      end
    end.join

    @mutex.synchronize do
      @pause_thread.join if @pause_thread
      @pause_thread = nil
    end

    Sidekiq.redis { |r| r.del(paused_key) }
    true
  end

  private

  def start_pause_thread
    Thread.new do
      while @paused do
        # TODO retries in case bad redis connectivity
        Sidekiq.redis do |r|
          r.setex paused_key, 60, "paused"
        end

        @mutex.synchronize do
          return unless @paused
          @done.wait(@mutex, 30)
        end
      end
    end
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

  attr_reader :delay

  def initialize(delay = 5.seconds)
    @delay = delay
  end

  def call(worker, msg, queue)
    if Sidekiq.paused?
      worker.class.perform_in(delay, *msg['args'])
    else
      yield
    end
  end

end

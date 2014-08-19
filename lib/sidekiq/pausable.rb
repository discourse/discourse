require 'thread'

class SidekiqPauser
  def initialize
    @mutex = Mutex.new
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
    @mutex.synchronize do
      if @pause_thread
        @paused = false
      end
      @pause_thread.kill
      @pause_thread.join
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
        sleep 30
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

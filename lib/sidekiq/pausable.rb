module Sidekiq

  def self.pause!
    Sidekiq.redis { |r| r.set(paused_key, 1) }
    true
  end

  def self.paused?
    Sidekiq.redis { |r| !!r.get(paused_key) }
  end

  def self.unpause!
    Sidekiq.redis { |r| r.del(paused_key) }
    true
  end

  private

  def self.paused_key
    "sidekiq_is_paused"
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

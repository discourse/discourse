require 'thread'

class SidekiqPauser
  TTL = 60
  PAUSED_KEY = "sidekiq_is_paused_v2"

  def initialize
    @mutex = Mutex.new
    @dbs ||= Set.new
  end

  def pause!
    $redis.setex PAUSED_KEY, TTL, "paused"

    @mutex.synchronize do
      extend_lease_thread
      sleep 0.001 while !paused?
    end

    true
  end

  def paused?
    !!$redis.get(PAUSED_KEY)
  end

  def unpause!
    @mutex.synchronize do
      @dbs.delete(RailsMultisite::ConnectionManagement.current_db)
      @extend_lease_thread = nil if @dbs.size == 0
    end

    $redis.del(PAUSED_KEY)
    true
  end

  private

  def extend_lease_thread
    @dbs << RailsMultisite::ConnectionManagement.current_db

    @extend_lease_thread ||= Thread.new do
      while true do
        break unless @mutex.synchronize { @extend_lease_thread }

        @dbs.each do |db|
          RailsMultisite::ConnectionManagement.with_connection(db) do
            $redis.expire PAUSED_KEY, TTL
          end
        end

        sleep(Rails.env.test? ? 0.01 : TTL / 2)
      end
    end
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
    if sidekiq_paused?(msg) && !(Jobs::RunHeartbeat === worker)
      worker.class.perform_in(@delay, *msg['args'])
    else
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      DiscourseEvent.trigger(:sidekiq_job_ran, worker, msg, queue, duration)
      result
    end
  end

  private

  def sidekiq_paused?(msg)
    if site_id = msg["args"]&.first&.dig("current_site_id")
      RailsMultisite::ConnectionManagement.with_connection(site_id) do
        Sidekiq.paused?
      end
    end
  end

end

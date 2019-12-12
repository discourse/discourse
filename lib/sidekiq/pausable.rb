# frozen_string_literal: true

require 'thread'

class SidekiqPauser
  TTL = 60
  PAUSED_KEY = "sidekiq_is_paused_v2"

  def initialize
    @mutex = Mutex.new
    @dbs ||= Set.new
  end

  def pause!(value = "paused")
    Discourse.redis.setex PAUSED_KEY, TTL, value
    extend_lease_thread
    true
  end

  def paused?
    !!Discourse.redis.get(PAUSED_KEY)
  end

  def unpause_all!
    @mutex.synchronize do
      @dbs = Set.new
      stop_extend_lease_thread
    end

    RailsMultisite::ConnectionManagement.each_connection do
      unpause! if paused?
    end
  end

  def paused_dbs
    dbs = []

    RailsMultisite::ConnectionManagement.each_connection do
      dbs << RailsMultisite::ConnectionManagement.current_db if paused?
    end

    dbs
  end

  def unpause!
    @mutex.synchronize do
      @dbs.delete(RailsMultisite::ConnectionManagement.current_db)
      stop_extend_lease_thread if @dbs.size == 0
    end

    Discourse.redis.del(PAUSED_KEY)
    true
  end

  private

  def stop_extend_lease_thread
    # should always be called from a mutex
    if t = @extend_lease_thread
      @extend_lease_thread = nil
      while t.alive?
        begin
          t.wakeup
        rescue ThreadError => e
          unless e.message =~ /killed thread/
            raise e
          end
        end

        sleep 0
      end
    end
  end

  def extend_lease_thread
    @mutex.synchronize do
      @dbs << RailsMultisite::ConnectionManagement.current_db

      @extend_lease_thread ||= Thread.new do
        while true do
          break if !@extend_lease_thread

          @mutex.synchronize do
            @dbs.each do |db|
              RailsMultisite::ConnectionManagement.with_connection(db) do
                if !Discourse.redis.expire(PAUSED_KEY, TTL)
                  # if it was unpaused in another process we got to remove the
                  # bad key
                  @dbs.delete(db)
                end
              end
            end
          end

          sleep(Rails.env.test? ? 0.01 : TTL / 2)
        end
      end
    end
  end
end

module Sidekiq
  @pauser = SidekiqPauser.new

  def self.pause!(key = nil)
    key ? @pauser.pause!(key) : @pauser.pause!
  end

  def self.paused?
    @pauser.paused?
  end

  def self.unpause!
    @pauser.unpause!
  end

  def self.unpause_all!
    @pauser.unpause_all!
  end

  def self.paused_dbs
    @pauser.paused_dbs
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

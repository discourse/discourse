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

  def self.dispose_v8_contexts
    PrettyText.reset_context
    AssetProcessor.reset_context
    ObjectSpace.each_object(MiniRacer::Context, &:dispose)
  end

  class DrainTimeout < StandardError
  end

  module PersistentService
    def outdated?
      false
    end
  end

  module PromotionGuard
    def spawn_mold(worker)
      unless GlobalSetting.mini_racer_single_threaded
        logger.warn("#{worker.to_log} skipping refork: mini_racer_single_threaded is disabled")
        return false
      end

      super
    rescue DrainTimeout
      logger.info("#{worker.to_log} refork drain timed out; resuming requests")
      false
    end

    private

    def fork_sibling(role, &block)
      return super unless role == "spawn_mold"

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @spawn_timeout * 0.9

      loop do
        if Pitchfork::FORK_LOCK.try_enter
          begin
            result =
              Scheduler::Defer.with_idle do
                next false unless Scheduler::ThreadPool.idle?

                PitchforkReforking.dispose_v8_contexts
                super
              end
            return result if result
          ensure
            Pitchfork::FORK_LOCK.exit
          end
        end

        raise DrainTimeout if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.01
      end
    end
  end
end

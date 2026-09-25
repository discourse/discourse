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

  module PromotionGuard
    def spawn_mold(worker)
      unless GlobalSetting.mini_racer_single_threaded
        logger.warn("#{worker.to_log} skipping refork: mini_racer_single_threaded is disabled")
        return false
      end

      unless Pitchfork::FORK_LOCK.try_enter
        logger.info("#{worker.to_log} skipping refork: JavaScript execution is active")
        return false
      end

      begin
        attempted = false
        result =
          Scheduler::Defer.with_idle do
            attempted = true
            super
          end
        logger.info("#{worker.to_log} skipping refork: deferred work is pending") unless attempted
        result
      ensure
        Pitchfork::FORK_LOCK.exit
      end
    end
  end
end

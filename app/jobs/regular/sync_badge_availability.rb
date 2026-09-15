# frozen_string_literal: true

module Jobs
  class SyncBadgeAvailability < ::Jobs::Base
    PENDING_KEY = "sync_badge_availability_pending"
    PENDING_TTL = 10.minutes

    def self.enqueue(plugin_name = nil)
      key = "#{PENDING_KEY}:#{plugin_name}"
      return unless Discourse.redis.set(key, "1", nx: true, ex: PENDING_TTL.to_i)

      begin
        Jobs.enqueue(self, plugin_name:)
      rescue StandardError
        Discourse.redis.del(key)
        raise
      end
    end

    def execute(args)
      Discourse.redis.del("#{PENDING_KEY}:#{args[:plugin_name]}")
      BadgeGranter.sync_availability!(args[:plugin_name])
    end
  end
end

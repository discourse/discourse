# frozen_string_literal: true

module Jobs
  # Deliveries to untrusted push hosts wait in a per-site Redis list and are drained by
  # one job at a time per site, so slow hosts can occupy at most one worker per site and
  # a backlog costs a single queued job rather than one retrying job per delivery.
  class DeliverUntrustedPushNotifications < ::Jobs::Base
    QUEUE_KEY = "untrusted_push_notifications"
    LOCK_KEY = "untrusted_push_notifications_lock"
    MAX_QUEUED = 1000
    MAX_RUN_DURATION = 60.seconds
    # Covers a full run plus one last delivery, so the lock only expires early if the
    # worker dies.
    LOCK_TTL = 3.minutes
    MAX_DELAY = 30.minutes

    def self.add(user_id:, message:, subscription_id: nil)
      entry = {
        user_id: user_id,
        message: message,
        subscription_id: subscription_id,
        enqueued_at: Time.zone.now.to_i,
      }

      Discourse.redis.rpush(QUEUE_KEY, entry.to_json)
      Discourse.redis.ltrim(QUEUE_KEY, -MAX_QUEUED, -1)
      Jobs.enqueue(:deliver_untrusted_push_notifications)
    end

    def execute(args)
      token = SecureRandom.hex
      # The lock holder drains every queued entry, including the ones added by the
      # jobs that return here.
      return if !Discourse.redis.set(LOCK_KEY, token, nx: true, ex: LOCK_TTL.to_i)

      begin
        drain
      ensure
        Discourse.redis.del(LOCK_KEY) if Discourse.redis.get(LOCK_KEY) == token
      end

      # Entries added while the lock was held, or left over when the run stopped,
      # would otherwise wait for the next delivery to come along.
      Jobs.enqueue(:deliver_untrusted_push_notifications) if Discourse.redis.llen(QUEUE_KEY) > 0
    end

    private

    def drain
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_RUN_DURATION

      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline &&
              (entry = Discourse.redis.lpop(QUEUE_KEY))
        deliver(JSON.parse(entry))
      end
    end

    def deliver(entry)
      return if Time.zone.at(entry["enqueued_at"].to_i) < MAX_DELAY.ago

      user = User.find_by(id: entry["user_id"])
      return if !user

      PushNotificationPusher.push_untrusted(
        user,
        entry["message"].deep_symbolize_keys,
        subscription_id: entry["subscription_id"],
      )
    rescue StandardError => e
      Discourse.warn_exception(
        e,
        message: "Failed to deliver untrusted push notification",
        env: {
          user_id: entry["user_id"],
        },
      )
    end
  end
end

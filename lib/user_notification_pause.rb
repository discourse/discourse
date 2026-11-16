# frozen_string_literal: true

# Manages timed notification pauses. Supply both source and key to identify a
# pause that can be ended independently; omit both for a manual pause.
class UserNotificationPause
  CANCELLED = "cancelled"

  # Retain ended keys long enough to reject delayed start requests.
  CANCELLATION_TTL = 1.day

  def initialize(user:)
    @user = user
  end

  # Repeated keyed starts reuse the original timing. An ended key returns nil,
  # so callers must choose a fresh key for each new pause.
  def start(ends_at:, source: nil, key: nil)
    redis_key = pause_redis_key(source:, key:)
    timing =
      synchronize do
        if redis_key && (stored_value = Discourse.redis.get(redis_key))
          next if stored_value == CANCELLED
          next @user.do_not_disturb_timings.find_by(id: stored_value)
        end

        new_timing = @user.do_not_disturb_timings.create(starts_at: Time.zone.now, ends_at:)
        if redis_key && new_timing.persisted?
          ttl = [(ends_at - Time.zone.now).ceil, CANCELLATION_TTL.to_i].max
          Discourse.redis.setex(redis_key, ttl, new_timing.id)
        end
        new_timing
      end

    publish_status if timing&.persisted?
    timing
  end

  # Ending before starting also cancels a delayed start for this key.
  def end(source:, key:)
    redis_key = pause_redis_key(source:, key:)
    raise ArgumentError, "source and key are required" unless redis_key

    synchronize do
      stored_value = Discourse.redis.get(redis_key)
      timing = @user.do_not_disturb_timings.find_by(id: stored_value) if stored_value != CANCELLED
      Discourse.redis.setex(redis_key, CANCELLATION_TTL.to_i, CANCELLED)
      timing&.destroy!
    end

    announce_and_deliver
  end

  # Explicitly resumes all active pauses, including scheduled pauses.
  def end_all
    synchronize { @user.active_do_not_disturb_timings.destroy_all }
    announce_and_deliver
  end

  private

  def synchronize(&)
    DistributedMutex.synchronize("user_notification_pause:#{@user.id}:lock", &)
  end

  def pause_redis_key(source:, key:)
    return if source.nil? && key.nil?
    raise ArgumentError, "source and key must both be present" if source.blank? || key.blank?

    identity = Digest::SHA256.hexdigest([source, key].to_json)
    "user_notification_pause:#{@user.id}:#{identity}"
  end

  def publish_status
    @user.publish_do_not_disturb(ends_at: @user.do_not_disturb_until)
  end

  def announce_and_deliver
    publish_status
    return if @user.do_not_disturb?

    shelved_notifications = @user.shelved_notifications
    shelved_notifications.each(&:process)
    shelved_notifications.destroy_all
  end
end

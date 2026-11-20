# frozen_string_literal: true

# Holds push notifications for a new post until its translation into the
# recipient's locale is stored, so they don't go out in the original language.
#
# A held push is released when that translation is stored, when the translator
# reports it is done with the post, or when the wait limit passes. All of them may
# fire for the same push, so delivery claims the push first and only one sends it.
class PushNotificationLocalizationWait
  DONE_FIELD = "done"
  HELD_PREFIX = "held:"
  CLAIMED_PREFIX = "claimed:"
  # Outlives the wait limit by far, so deliveries delayed by a backed-up queue can
  # still claim their push.
  TTL = 1.day

  # @param post_id [Integer]
  # @param locale [String] The recipient's locale
  # @param job_args [Hash] Arguments of the push delivery job being held
  # @return [String] Token identifying the held push, passed to {.claim}
  def self.hold(post_id:, locale:, job_args:)
    token = SecureRandom.hex(8)
    args = job_args.except(:current_site_id).merge(localization_wait_token: token)
    limit = SiteSetting.push_notification_localization_max_wait_mins.minutes

    Discourse.redis.multi do |transaction|
      transaction.hset(key(post_id), "#{HELD_PREFIX}#{token}", { locale:, args: }.to_json)
      transaction.expire(key(post_id), TTL)
    end
    Jobs.enqueue_in(limit, :deliver_push_notification, args)

    token
  end

  # Records claims rather than removing held pushes, so a push whose state has
  # expired is still delivered.
  # @return [Boolean] Whether the caller is the one that must deliver the push
  def self.claim(post_id, token)
    claimed, _ =
      Discourse.redis.multi do |transaction|
        transaction.hsetnx(key(post_id), "#{CLAIMED_PREFIX}#{token}", "1")
        transaction.hdel(key(post_id), "#{HELD_PREFIX}#{token}")
        transaction.expire(key(post_id), TTL)
      end
    claimed
  end

  # For a delivery that failed after claiming, so another one can send the push.
  def self.unclaim(post_id, token)
    Discourse.redis.hdel(key(post_id), "#{CLAIMED_PREFIX}#{token}")
  end

  # @return [Boolean] Whether the translator is done with the post
  def self.done?(post_id)
    Discourse.redis.hexists(key(post_id), DONE_FIELD)
  end

  # Delivers pushes held for recipients reading `locale`, or all of them.
  def self.release(post_id, locale: nil)
    Discourse
      .redis
      .hgetall(key(post_id))
      .each do |field, value|
        next if !field.start_with?(HELD_PREFIX)

        held = JSON.parse(value)
        next if locale && !LocaleNormalizer.is_same?(held["locale"], locale)

        Jobs.enqueue(:deliver_push_notification, held["args"])
      end
  end

  def self.finish(post_id)
    Discourse.redis.multi do |transaction|
      transaction.hset(key(post_id), DONE_FIELD, "1")
      transaction.expire(key(post_id), TTL)
    end
    release(post_id)
  end

  def self.key(post_id)
    "push_notification_localization_wait:#{post_id}"
  end
  private_class_method :key
end

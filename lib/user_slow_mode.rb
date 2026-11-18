# frozen_string_literal: true

class UserSlowMode
  MIN_SECONDS = 1.minute.to_i
  MAX_SECONDS = 7.days.to_i

  class << self
    def applies_to?(user, args)
      return false unless active?(user)

      if args[:topic_id].present?
        !Topic.where(id: args[:topic_id], archetype: Archetype.private_message).exists?
      else
        args[:archetype] != Archetype.private_message
      end
    end

    def synchronize(user, &block)
      DistributedMutex.synchronize("user_slow_mode_#{user.id}", &block)
    end

    def posting_error(user)
      return unless active?(user)

      if ReviewableQueuedPost.pending.where(target_created_by_id: user.id).exists?
        return I18n.t("user_slow_mode.pending")
      end

      now = Time.zone.now
      last_post_at =
        Post
          .with_deleted
          .joins("INNER JOIN topics ON topics.id = posts.topic_id")
          .where(user_id: user.id, post_type: Post.types[:regular])
          .where(topics: { archetype: Archetype.default })
          .where("posts.created_at > ?", now - user.user_slow_mode_seconds)
          .maximum(:created_at)
      return unless last_post_at

      next_at = [last_post_at + user.user_slow_mode_seconds, user.user_slow_mode_until].compact.min
      wait = (next_at - now).ceil
      I18n.t("user_slow_mode.wait", time_left: RateLimiter.time_left(wait)) if wait > 0
    end

    def summary(user)
      return unless active?(user)

      { seconds: user.user_slow_mode_seconds, ends_at: user.user_slow_mode_until&.iso8601 }
    end

    def update!(user, guardian:, seconds:, ends_at:)
      interval = Integer(seconds.to_s, 10, exception: false)
      if interval.nil? ||
           !(
             interval.zero? ||
               (interval.between?(MIN_SECONDS, MAX_SECONDS) && (interval % 60).zero?)
           )
        raise Discourse::InvalidParameters.new(I18n.t("user_slow_mode.invalid_interval"))
      end
      end_time = parse_end_time(ends_at) if interval.positive?

      synchronize(user) do
        user.with_lock do
          guardian.ensure_can_set_user_slow_mode!(user)
          previous = summary(user)
          user.update!(user_slow_mode_seconds: interval, user_slow_mode_until: end_time)
          current = summary(user)

          if user.saved_change_to_user_slow_mode_seconds? ||
               user.saved_change_to_user_slow_mode_until?
            UserHistory.create!(
              action: UserHistory.actions[:user_slow_mode_changed],
              acting_user: guardian.user,
              target_user: user,
              previous_value: previous.to_json,
              new_value: current.to_json,
            )
          end

          current
        end
      end
    end

    private

    def active?(user)
      SiteSetting.enable_user_slow_mode && user.human? && !user.staff? &&
        user.user_slow_mode_seconds.positive? &&
        (user.user_slow_mode_until.nil? || user.user_slow_mode_until.future?)
    end

    def parse_end_time(value)
      return if value.blank?

      time = Time.iso8601(value.to_s)
      raise ArgumentError unless time.future?
      time
    rescue ArgumentError
      raise Discourse::InvalidParameters.new(I18n.t("user_slow_mode.invalid_end_time"))
    end
  end
end

# frozen_string_literal: true

module Voice
  class UserStatusManager
    EMOJI = "studio_microphone"
    AFK_EMOJI = "zzz"
    # Users whose current status was written by us. Emoji alone can't identify
    # ownership — anyone can pick zzz from the status picker — and the sweep
    # must never touch a status it didn't set. Self-healing: heartbeats
    # re-add, and Redis drops the key once the set empties.
    OWNERS_KEY = "voice:status_owners"
    # A status younger than this is skipped by the sweep: it may have been set
    # by a join that raced the sweep's liveness snapshot, and the heartbeat
    # only refreshes statuses that still exist, so a wrong clear would stick.
    STALE_GRACE_PERIOD = 30.seconds

    class << self
      # Statuses carry no ends_at: they mirror room presence, not a timer, so
      # the tooltip shows no "until" line. Leave/kick clear them directly;
      # crashed or lapsed clients are reaped by clear_stale_statuses.
      def set_voice_status(user, room)
        return unless SiteSetting.enable_user_status
        return unless SiteSetting.voice_auto_status_enabled
        return if user_has_non_voice_status?(user)

        set_status(user, status_description(room), EMOJI)
      end

      def set_afk_status(user, room)
        return unless SiteSetting.enable_user_status
        return unless voice_status_active?(user)

        set_status(user, status_description(room, afk: true), AFK_EMOJI)
      end

      def clear_voice_status(user)
        return unless SiteSetting.enable_user_status

        Discourse.redis.srem(OWNERS_KEY, user.id)
        return unless voice_status_active?(user)

        user.clear_status!
      end

      # Reaps owned statuses whose user is no longer live in any room — the
      # backstop for exits that never hit leave/kick (crashed client, dead
      # network, sleeping laptop). Only statuses we set are candidates.
      def clear_stale_statuses(live_user_ids)
        return unless SiteSetting.enable_user_status

        owner_ids = Discourse.redis.smembers(OWNERS_KEY).map(&:to_i)
        stale_ids = owner_ids - live_user_ids
        return if stale_ids.empty?

        released_ids = []
        users_by_id = User.where(id: stale_ids).includes(:user_status).index_by(&:id)
        stale_ids.each do |user_id|
          user = users_by_id[user_id]
          status = user&.user_status

          if user.nil? || status.nil? || !voice_emoji?(status.emoji)
            # Deleted user, or the status was since cleared/replaced: ownership
            # lapsed on its own.
            released_ids << user_id
          elsif status.set_at <= STALE_GRACE_PERIOD.ago
            user.clear_status!
            released_ids << user_id
          end
          # Within the grace window: a join may have raced this sweep's liveness
          # snapshot — the next run decides.
        end

        Discourse.redis.srem(OWNERS_KEY, released_ids) if released_ids.any?
      end

      def voice_status_active?(user)
        status = user.user_status
        status && !status.expired? && voice_emoji?(status.emoji)
      end

      # Statuses are visible site-wide, so a non-public room's name must not
      # appear in them — even room members get the generic description.

      private

      def status_description(room, afk: false)
        prefix = afk ? "afk_" : ""
        if room.public?
          I18n.t("voice.user_status.#{prefix}in_room", room_name: room.name)
        else
          I18n.t("voice.user_status.#{prefix}in_private_room")
        end
      end

      # Without an expiry to roll, an unchanged status needs no upsert — this
      # keeps the every-beat heartbeat call from republishing over message bus.
      # A matching status that still carries an ends_at (written before expiries
      # were dropped) must be rewritten, or it would expire out from under a
      # live user.
      def set_status(user, description, emoji)
        status = user.user_status
        unless status && status.ends_at.nil? && status.description == description &&
                 status.emoji == emoji
          user.set_status!(description, emoji)
        end

        Discourse.redis.sadd(OWNERS_KEY, user.id)
      end

      def user_has_non_voice_status?(user)
        status = user.user_status
        status && !status.expired? && !voice_emoji?(status.emoji)
      end

      def voice_emoji?(emoji)
        [EMOJI, AFK_EMOJI].include?(emoji)
      end
    end
  end
end

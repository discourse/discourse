# frozen_string_literal: true

module Voice
  class BadgeGranterHooks
    def self.on_leave(user, session, room:)
      return unless badges_enabled?
      return if session&.left_at.blank?

      grant("Mic Check", user) if mic_check?(session, room)
      grant("Night Owl", user) if night_owl?(user, session)
      grant("Early Bird", user) if early_bird?(user, session)
      grant("Marathoner", user) if marathoner?(session)
    end

    def self.on_join(user, room, participants)
      return unless badges_enabled?

      grant("Packed House", user) if room_full?(room, participants)
      grant("Icebreaker", user) if icebreaker?(user, participants)
    end

    def self.on_room_create(user)
      return unless badges_enabled?
      grant("Host", user)
    end

    def self.on_invite_redeemed(invite)
      return unless badges_enabled?

      inviter = invite.invited_by
      grant("Plus One", inviter) if inviter
    end

    BADGE_GROUP_NAME = "Voice"

    # The site setting is a master switch over the whole grouping. Badges are
    # flipped in bulk, so the per-badge save callbacks that keep user badge
    # counts consistent run once here instead.
    def self.enable_all!
      badges = voice_badges
      badges.update_all(enabled: true)
      sync_user_badges!
      badges
        .where.not(query: nil)
        .pluck(:id)
        .each { |badge_id| Jobs.enqueue(:backfill_badge, badge_id: badge_id) }
    end

    def self.disable_all!
      voice_badges.update_all(enabled: false)
      sync_user_badges!
    end

    class << self
      private

      def grant(badge_name, user)
        badge = Badge.find_by(name: badge_name)
        BadgeGranter.grant(badge, user) if badge&.enabled?
      end

      def mic_check?(session, room)
        duration = (session.left_at - session.joined_at).to_i
        duration >= 30 && Voice::ParticipantTracker.user_ids(room.id).any?
      end

      def night_owl?(user, session)
        hour = local_hour(user, session.joined_at)
        hour >= 0 && hour < 5
      end

      def early_bird?(user, session)
        hour = local_hour(user, session.joined_at)
        hour >= 5 && hour < 9
      end

      def marathoner?(session)
        session.accompanied_seconds >= 4.hours.to_i
      end

      def room_full?(room, participants)
        participants.count >= room.effective_max_participants
      end

      def icebreaker?(user, participants)
        other_ids = participants.map(&:id) - [user.id]
        return false if other_ids.empty?

        Voice::CoPresence
          .where("(user_id_1 = :uid OR user_id_2 = :uid)", uid: user.id)
          .where("(user_id_1 IN (:others) OR user_id_2 IN (:others))", others: other_ids)
          .none?
      end

      def local_hour(user, time)
        tz = user.user_option&.timezone.presence || "UTC"
        time.in_time_zone(tz).hour
      end

      def voice_badges
        Badge.joins(:badge_grouping).where(badge_groupings: { name: BADGE_GROUP_NAME })
      end

      def sync_user_badges!
        UserBadge.ensure_consistency!
        UserStat.update_distinct_badge_count
      end

      # Every badge here is derived from analytics sessions, so without them
      # nothing can be earned.
      def badges_enabled?
        SiteSetting.enable_badges && SiteSetting.voice_badges_enabled &&
          SiteSetting.voice_analytics_enabled
      end
    end
  end
end

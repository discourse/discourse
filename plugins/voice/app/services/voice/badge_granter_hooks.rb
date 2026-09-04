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

    def self.enable_all!
      grouping = BadgeGrouping.find_by(name: BADGE_GROUP_NAME)
      Badge.where(badge_grouping_id: grouping.id).update_all(enabled: true) if grouping
    end

    def self.disable_all!
      grouping = BadgeGrouping.find_by(name: BADGE_GROUP_NAME)
      Badge.where(badge_grouping_id: grouping.id).update_all(enabled: false) if grouping
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
        duration = (session.left_at - session.joined_at).to_i
        duration >= 4.hours.to_i
      end

      def room_full?(room, participants)
        room.max_participants.present? && participants.count >= room.max_participants
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

      def badges_enabled?
        SiteSetting.enable_badges && SiteSetting.voice_badges_enabled
      end
    end
  end
end

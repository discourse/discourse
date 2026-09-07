# frozen_string_literal: true

module Voice
  # Who may publish camera and screen media, answered for a whole roster at
  # once. Mesh peers attach media straight to each other, so a receiver has to
  # know every sender's entitlement — not just its own — before it plays a
  # video or screen-audio track; the roster carries these alongside each
  # participant.
  #
  # Deliberately excludes the stage role, which clients already follow live
  # through role_change broadcasts, and which would otherwise make every
  # promotion a stale-payload bug.
  class MediaEntitlements
    NONE = { can_publish_video: false, can_screen_share: false }.freeze

    class << self
      def for_users(room, users)
        users = Array(users)
        return {} if users.blank?
        return users.to_h { |user| [user.id, NONE] } if !room || !room.video_enabled?

        video_ids = user_ids_in_groups(users, SiteSetting.voice_video_allowed_groups_map)
        screen_ids = user_ids_in_groups(users, SiteSetting.voice_screen_share_allowed_groups_map)

        users.to_h do |user|
          [
            user.id,
            {
              can_publish_video: video_ids.include?(user.id),
              can_screen_share: screen_ids.include?(user.id),
            },
          ]
        end
      end

      def for_user(room, user)
        return NONE if user.blank?
        for_users(room, [user])[user.id] || NONE
      end

      private

      # Only `everyone` and `logged_in_users` carry no group_users rows, so
      # core's own predicate decides those two (it also owns how `everyone` is
      # read); everything else, auto groups included, is one query.
      def user_ids_in_groups(users, group_ids)
        return Set.new if group_ids.blank?

        pseudo_groups =
          group_ids & [Group::AUTO_GROUPS[:everyone], Group::AUTO_GROUPS[:logged_in_users]]
        if pseudo_groups.present? && users.first.in_any_groups?(pseudo_groups)
          return users.map(&:id).to_set
        end

        GroupUser.where(group_id: group_ids, user_id: users.map(&:id)).pluck(:user_id).to_set
      end
    end
  end
end

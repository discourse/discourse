# frozen_string_literal: true

module Jobs
  class LivestreamRecalculateUserChannelMemberships < ::Jobs::Base
    def execute
      if !SiteSetting.calendar_enabled || !SiteSetting.discourse_post_event_enabled ||
           !SiteSetting.livestream_enabled
        return
      end

      going = DiscoursePostEvent::Invitee.statuses[:going]
      query = <<~SQL
        WITH attending_users AS (
          SELECT u.*
          FROM discourse_post_event_invitees dpei
          JOIN users u ON dpei.user_id = u.id
          WHERE dpei.status = :going
        )
        SELECT uccm.*
          FROM livestream_topic_chat_channels ltcc
          JOIN chat_channels cc ON cc.id = ltcc.chat_channel_id
          JOIN user_chat_channel_memberships uccm ON cc.id = uccm.chat_channel_id
          JOIN attending_users au ON au.id = uccm.user_id
      SQL
      memberships = ::Chat::UserChatChannelMembership.find_by_sql([query, { going: going }])

      memberships.each do |membership|
        user = membership.user
        ActiveRecord::Base.transaction do
          is_user_allowed_in_livestream_chat = user_allowed_in_livestream_chat?(user)
          if membership.following != is_user_allowed_in_livestream_chat
            membership.update!(following: is_user_allowed_in_livestream_chat)
            ::Chat::ChannelMembershipManager.new(membership.chat_channel).recalculate_user_count
          end
        end

        ::DiscourseCalendar::Livestream.publish_livestream_chat_status(
          membership.reload,
          user: user,
        )
      end
    end

    private

    def user_allowed_in_livestream_chat?(user)
      user.in_any_groups?(SiteSetting.livestream_chat_allowed_groups_map)
    end
  end
end

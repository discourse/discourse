# frozen_string_literal: true

module Jobs
  module Chat
    class UnmuteExpiredChannelMemberships < ::Jobs::Scheduled
      every 1.minute

      def execute(args = nil)
        return if !SiteSetting.chat_enabled

        memberships = DB.query(<<~SQL, now: Time.zone.now)
          UPDATE user_chat_channel_memberships
          SET muted = FALSE, muted_until = NULL, updated_at = :now
          WHERE muted_until <= :now
          RETURNING user_id, chat_channel_id, muted, muted_until
        SQL

        memberships.each { |membership| ::Chat::Publisher.publish_user_channel_mute!(membership) }
      end
    end
  end
end

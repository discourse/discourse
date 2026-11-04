# frozen_string_literal: true

module Jobs
  module Chat
    class UnmuteExpiredChannelMemberships < ::Jobs::Scheduled
      every 1.minute

      def execute(args = nil)
        return if !SiteSetting.chat_enabled

        ::Chat::UserChatChannelMembership.with_expired_mute.find_each do |membership|
          # Only unmute if the mute hasn't changed since we loaded it, so a
          # user re-muting at the same moment keeps their new mute.
          unmuted =
            ::Chat::UserChatChannelMembership.where(
              id: membership.id,
              muted_until: membership.muted_until,
            ).update_all(muted: false, muted_until: nil, updated_at: Time.zone.now)

          next if unmuted.zero?

          membership.assign_attributes(muted: false, muted_until: nil)
          ::Chat::Publisher.publish_user_channel_mute!(membership)
        end
      end
    end
  end
end

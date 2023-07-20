# frozen_string_literal: true

module Jobs
  module Chat
    class KickUsersFromChannel < Jobs::Base
      def execute(args)
        return if !::Chat::Channel.exists?(id: args[:channel_id])
        return if args[:user_ids].blank?
        ::Chat::Publisher.publish_kick_users(args[:channel_id], args[:user_ids])
      end
    end
  end
end

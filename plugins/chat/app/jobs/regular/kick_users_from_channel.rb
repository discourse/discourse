# frozen_string_literal: true

module Jobs
  class KickUsersFromChannel < Jobs::Base
    def execute(args)
      return if !ChatChannel.exists?(id: args[:channel_id])
      return if args[:user_ids].blank?
      ChatPublisher.publish_kick_users(args[:channel_id], args[:user_ids])
    end
  end
end

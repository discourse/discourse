# frozen_string_literal: true

module Jobs
  class AutoRemoveChannelMemberships < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemoveMembershipEventHandler.call(
        event_type: args[:event_type],
        event_data: args[:event_data],
      )
    end
  end
end

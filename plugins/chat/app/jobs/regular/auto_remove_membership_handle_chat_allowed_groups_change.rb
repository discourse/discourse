# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleChatAllowedGroupsChange < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemove::HandleChatAllowedGroupsChange.call(
        new_allowed_groups: args[:new_allowed_groups],
      )
    end
  end
end

# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleChatAllowedGroupsChange < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemove::HandleChatAllowedGroupsChange.call(**args)
    end
  end
end

# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleUserRemovedFromGroup < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemove::HandleUserRemovedFromGroup.call(**args)
    end
  end
end

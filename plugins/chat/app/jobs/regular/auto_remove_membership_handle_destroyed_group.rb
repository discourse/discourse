# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleDestroyedGroup < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemove::HandleDestroyedGroup.call(**args)
    end
  end
end

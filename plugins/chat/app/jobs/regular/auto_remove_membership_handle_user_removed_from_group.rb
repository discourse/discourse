# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleUserRemovedFromGroup < ::Jobs::Base
    def execute(args)
      Chat::Service::AutoRemove::HandleUserRemovedFromGroup.call(**args)
    end
  end
end

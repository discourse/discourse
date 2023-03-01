# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleDestroyedGroup < ::Jobs::Base
    def execute(args)
      Chat::Service::AutoRemove::HandleDestroyedGroup.call(**args)
    end
  end
end

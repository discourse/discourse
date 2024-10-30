# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleUserRemovedFromGroup < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleUserRemovedFromGroup.call(params: args)
      end
    end
  end
end

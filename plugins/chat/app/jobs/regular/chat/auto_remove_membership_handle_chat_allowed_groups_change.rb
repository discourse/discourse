# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleChatAllowedGroupsChange < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleChatAllowedGroupsChange.call(params: args)
      end
    end
  end
end

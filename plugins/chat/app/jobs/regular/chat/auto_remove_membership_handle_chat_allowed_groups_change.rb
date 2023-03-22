# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleChatAllowedGroupsChange < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleChatAllowedGroupsChange.call(**args)
      end
    end
  end
end

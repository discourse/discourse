# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleDestroyedGroup < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleDestroyedGroup.call(params: args)
      end
    end
  end
end

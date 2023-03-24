# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleDestroyedGroup < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleDestroyedGroup.call(**args)
      end
    end
  end
end

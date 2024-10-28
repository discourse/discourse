# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleCategoryUpdated < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleCategoryUpdated.call(params: args)
      end
    end
  end
end

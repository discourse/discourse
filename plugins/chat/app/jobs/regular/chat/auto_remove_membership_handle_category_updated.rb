# frozen_string_literal: true

module Jobs
  module Chat
    class AutoRemoveMembershipHandleCategoryUpdated < ::Jobs::Base
      def execute(args)
        ::Chat::AutoRemove::HandleCategoryUpdated.call(**args)
      end
    end
  end
end

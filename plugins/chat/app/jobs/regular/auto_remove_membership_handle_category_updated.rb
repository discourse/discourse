# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleCategoryUpdated < ::Jobs::Base
    def execute(args)
      Chat::Service::AutoRemove::HandleCategoryUpdated.call(**args)
    end
  end
end

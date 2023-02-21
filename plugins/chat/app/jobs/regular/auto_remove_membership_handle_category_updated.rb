# frozen_string_literal: true

module Jobs
  class AutoRemoveMembershipHandleCategoryUpdated < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.chat_enabled

      Chat::Service::AutoRemove::HandleCategoryUpdated.call(category_id: args[:category_id])
    end
  end
end

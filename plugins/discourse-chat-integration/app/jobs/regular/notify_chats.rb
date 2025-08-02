# frozen_string_literal: true

module Jobs
  class NotifyChats < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.chat_integration_enabled?
      ::DiscourseChatIntegration::Manager.trigger_notifications(args[:post_id])
    end
  end
end

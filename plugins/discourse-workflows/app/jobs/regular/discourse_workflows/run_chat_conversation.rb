# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class RunChatConversation < ::Jobs::Base
      def execute(args)
        if !SiteSetting.enable_discourse_workflows ||
             !::DiscourseWorkflows::ChatConversation.chat_available?
          return
        end

        ::DiscourseWorkflows::ChatConversation::Run.call(params: { message_id: args[:message_id] })
      end
    end
  end
end

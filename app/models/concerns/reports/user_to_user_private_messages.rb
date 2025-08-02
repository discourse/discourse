# frozen_string_literal: true

module Reports::UserToUserPrivateMessages
  extend ActiveSupport::Concern

  class_methods do
    def report_user_to_user_private_messages(report)
      report.icon = "envelope"
      private_messages_report report, TopicSubtype.user_to_user
    end
  end
end

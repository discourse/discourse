# frozen_string_literal: true

module Reports::NotifyUserPrivateMessages
  extend ActiveSupport::Concern

  class_methods do
    def report_notify_user_private_messages(report)
      report.icon = "envelope"
      private_messages_report report, TopicSubtype.notify_user
    end
  end
end

# frozen_string_literal: true

module Reports::NotifyModeratorsPrivateMessages
  extend ActiveSupport::Concern

  class_methods do
    def report_notify_moderators_private_messages(report)
      report.icon = "envelope"
      private_messages_report report, TopicSubtype.notify_moderators
    end
  end
end

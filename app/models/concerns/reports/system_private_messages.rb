# frozen_string_literal: true

module Reports::SystemPrivateMessages
  extend ActiveSupport::Concern

  class_methods do
    def report_system_private_messages(report)
      report.icon = "envelope"
      private_messages_report report, TopicSubtype.system_message
    end
  end
end

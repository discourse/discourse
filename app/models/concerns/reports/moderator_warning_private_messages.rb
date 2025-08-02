# frozen_string_literal: true

module Reports::ModeratorWarningPrivateMessages
  extend ActiveSupport::Concern

  class_methods do
    def report_moderator_warning_private_messages(report)
      report.icon = "envelope"
      private_messages_report report, TopicSubtype.moderator_warning
    end
  end
end

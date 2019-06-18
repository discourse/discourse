# frozen_string_literal: true

Report.add_report("moderator_warning_private_messages") do |report|
  report.icon = 'envelope'
  private_messages_report report, TopicSubtype.moderator_warning
end

# frozen_string_literal: true

Report.add_report("user_to_user_private_messages") do |report|
  report.icon = 'envelope'
  private_messages_report report, TopicSubtype.user_to_user
end

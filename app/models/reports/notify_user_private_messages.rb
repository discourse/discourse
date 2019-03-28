Report.add_report("notify_user_private_messages") do |report|
  report.icon = 'envelope'
  private_messages_report report, TopicSubtype.notify_user
end

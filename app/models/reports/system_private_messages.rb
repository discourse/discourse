Report.add_report("system_private_messages") do |report|
  report.icon = 'envelope'
  private_messages_report report, TopicSubtype.system_message
end

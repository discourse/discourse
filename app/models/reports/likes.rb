Report.add_report("likes") do |report|
  report.category_filtering = true
  report.icon = 'heart'
  post_action_report report, PostActionType.types[:like]
end

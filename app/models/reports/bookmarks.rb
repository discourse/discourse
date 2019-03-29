Report.add_report("bookmarks") do |report|
  report.category_filtering = true
  report.icon = 'bookmark'
  post_action_report report, PostActionType.types[:bookmark]
end

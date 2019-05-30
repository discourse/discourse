# frozen_string_literal: true

Report.add_report('bookmarks') do |report|
  report.icon = 'bookmark'

  post_action_report report, PostActionType.types[:bookmark]
end

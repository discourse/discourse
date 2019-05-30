# frozen_string_literal: true

Report.add_report("likes") do |report|
  report.icon = 'heart'

  post_action_report report, PostActionType.types[:like]
end

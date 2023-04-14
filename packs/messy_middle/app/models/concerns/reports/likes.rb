# frozen_string_literal: true

module Reports::Likes
  extend ActiveSupport::Concern

  class_methods do
    def report_likes(report)
      report.icon = "heart"

      post_action_report report, PostActionType.types[:like]
    end
  end
end

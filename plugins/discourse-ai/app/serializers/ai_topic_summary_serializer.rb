# frozen_string_literal: true

class AiTopicSummarySerializer < ApplicationSerializer
  attributes :summarized_text,
             :algorithm,
             :outdated,
             :can_regenerate,
             :new_posts_since_summary,
             :updated_at

  def can_regenerate
    scope.can_request_summary?
  end

  def new_posts_since_summary
    object.target.highest_post_number.to_i - object.highest_target_number.to_i
  end
end

# frozen_string_literal: true

class TopicSummarySerializer < ApplicationSerializer
  attributes :summarized_text, :algorithm, :outdated, :can_regenerate, :new_posts_since_summary

  def can_regenerate
    Summarization::Base.can_request_summary_for?(scope.current_user)
  end

  def new_posts_since_summary
    object.target.highest_post_number.to_i - object.content_range&.end.to_i
  end
end

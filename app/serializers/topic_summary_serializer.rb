# frozen_string_literal: true

class TopicSummarySerializer < ApplicationSerializer
  attributes :summarized_text, :algorithm, :outdated, :can_regenerate, :new_posts_since_summary

  def can_regenerate
    Summarization::Base.can_request_summary_for?(scope.current_user)
  end

  def new_posts_since_summary
    # Postgres uses discrete range types for int4range, which means
    # an inclusive [1,2] ranges is stored as [1,3). To work around this
    # an provide an accurate count, we do the following:
    range_end = [object.content_range&.end.to_i - 1, 0].max

    object.target.highest_post_number.to_i - range_end
  end
end

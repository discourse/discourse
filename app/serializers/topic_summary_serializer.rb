# frozen_string_literal: true

class TopicSummarySerializer < ApplicationSerializer
  attributes :summarized_text, :algorithm, :outdated, :can_regenerate, :new_posts_since_summary

  def can_regenerate
    Summarization::Base.can_request_summary_for?(scope.current_user)
  end

  def new_posts_since_summary
    # Postgres uses discrete range types for int4range, which means
    # (1..2) is stored as (1...3).
    #
    # We use Range#max to work around this, which in the case above always returns 2.
    # Be careful with using Range#end here, it could lead to unexpected results as:
    #
    # (1..2).end => 2
    # (1...3).end => 3

    object.target.highest_post_number.to_i - object.content_range&.max.to_i
  end
end

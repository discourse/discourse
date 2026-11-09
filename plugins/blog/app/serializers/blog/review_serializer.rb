# frozen_string_literal: true

module ::Blog
  class ReviewSerializer < BasicReviewSerializer
    attributes :title, :created_at, :expires_at, :revoked_by_publish, :active, :url, :feedback_count

    def active
      @options[:active_review_ids].include?(object.id)
    end

    def url
      object.url if active
    end

    def include_feedback_count?
      @options.key?(:feedback_counts)
    end

    def feedback_count
      @options[:feedback_counts].fetch(object.id, 0)
    end
  end
end

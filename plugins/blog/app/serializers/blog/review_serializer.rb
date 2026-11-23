# frozen_string_literal: true

module ::Blog
  class ReviewSerializer < BasicReviewSerializer
    attributes :title, :created_at, :expires_at, :revoked_by_publish, :active, :url, :feedback_count

    def active
      @options[:active_review_ids].include?(object.id)
    end

    # Every review in a list is for the same draft, so the caller passes its blog.
    def url
      return if !active
      @options[:blog] ? object.url(@options[:blog]) : object.url
    end

    def include_feedback_count?
      @options.key?(:feedback_counts)
    end

    def feedback_count
      @options[:feedback_counts].fetch(object.id, 0)
    end
  end
end

# frozen_string_literal: true

module ::Blog
  class ReviewFeedbackSerializer < ApplicationSerializer
    attributes :id, :name, :email, :message, :created_at

    has_one :review, serializer: BasicReviewSerializer, embed: :objects

    def include_review?
      @options[:include_review]
    end
  end
end

# frozen_string_literal: true

class Blog::Review::SubmitFeedback
  include Service::Base

  params do
    attribute :review_id, :integer
    attribute :feedback, :hash do
      attribute :name, :string
      attribute :email, :string
      attribute :message, :string
    end

    validates :review_id, :feedback, presence: true
  end

  model :review

  transaction do
    model :topic, :lock_topic
    step :lock_review
    policy :review_is_accessible
    policy :within_feedback_limit
    model :review_feedback, :create_review_feedback
  end

  private

  def fetch_review(params:)
    Blog::Review.find_by(id: params.review_id)
  end

  def lock_topic(review:)
    Topic.lock.find_by(id: review.topic_id)
  end

  # Post and topic callbacks revoke reviews without taking the topic lock, so
  # the review row is locked and reloaded too before its revoked_at is trusted.
  def lock_review(review:)
    review.lock!
  end

  def review_is_accessible(review:)
    review.accessible?
  end

  def within_feedback_limit(review:)
    review.feedback.count < Blog::Review::MAX_FEEDBACK
  end

  def create_review_feedback(params:, review:)
    review.feedback.create(params.feedback.to_hash)
  end
end

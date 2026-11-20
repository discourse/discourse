# frozen_string_literal: true

class Blog::Review::Revoke
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :review_id, :integer

    validates :topic_id, :review_id, presence: true
  end

  model :topic
  policy :can_edit_blog_topic

  transaction do
    step :lock_topic
    model :review
    only_if(:review_is_open) { step :revoke_review }
    step :log_revocation
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_edit_blog_topic(guardian:, topic:)
    guardian.can_edit_blog_topic?(topic)
  end

  def lock_topic(topic:)
    topic.lock!
  end

  def fetch_review(params:, topic:)
    Blog::Review.find_by(topic:, id: params.review_id)
  end

  def review_is_open(review:)
    review.revoked_at.nil?
  end

  def revoke_review(review:)
    review.update!(revoked_at: Time.current)
  end

  def log_revocation(guardian:, review:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_review_revoke",
      topic_id: review.topic_id,
      review_id: review.id,
    )
  end
end

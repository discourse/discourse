# frozen_string_literal: true

class Blog::Review::Create
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :label, :string

    validates :topic_id, presence: true

    before_validation { self.label = label.to_s }
  end

  model :topic
  policy :can_edit_blog_topic
  policy :blog_is_ready, class_name: Blog::Policy::Ready

  transaction do
    step :lock_topic
    step :lock_first_post
    policy :topic_is_reviewable
    policy :within_review_limit
    model :snapshot, :take_snapshot
    policy :snapshot_within_size_limit
    model :review, :create_review
    step :log_creation
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

  # Holds the post still so the snapshot matches the version that passed the checks.
  def lock_first_post(topic:)
    topic.first_post&.lock!
  end

  def topic_is_reviewable(topic:)
    Blog::Review.eligible_topic?(topic)
  end

  def within_review_limit(topic:)
    Blog::Review.where(topic:).unexpired.count < Blog::Review::MAX_ACTIVE_PER_TOPIC
  end

  def take_snapshot(topic:)
    Blog::Review.snapshot_html(topic.first_post)
  end

  def snapshot_within_size_limit(snapshot:)
    snapshot.bytesize <= Blog::Review::MAX_SNAPSHOT_BYTES
  end

  def create_review(params:, guardian:, topic:, snapshot:)
    Blog::Review.create(
      topic:,
      creator: guardian.user,
      label: params.label,
      title: topic.title,
      cooked: snapshot,
      post_version: topic.first_post.version,
      token: SecureRandom.urlsafe_base64(32),
      expires_at: Blog::Review::LIFETIME.from_now,
    )
  end

  def log_creation(guardian:, review:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_review_create",
      topic_id: review.topic_id,
      review_id: review.id,
    )
  end
end

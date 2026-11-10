# frozen_string_literal: true

class Blog::Publication::Schedule
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :revision_id, :integer
    attribute :scheduled_at, :datetime

    validates :topic_id, :revision_id, presence: true
    validate :scheduled_at_within_a_year

    private

    def scheduled_at_within_a_year
      return if scheduled_at&.after?(1.minute.from_now) && !scheduled_at.after?(1.year.from_now)
      errors.add(:base, I18n.t("blog.editorial.schedule_time"))
    end
  end

  model :topic

  transaction do
    model :publication, :lock_publication
    policy :can_publish_article
    policy :blog_ready, class_name: Blog::Policy::Ready
    model :revision
    policy :revision_is_approved
    step :schedule_release
    step :log_schedule
  end

  step :enqueue_release

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def lock_publication(topic:)
    Blog::Publication.lock_existing_for_topic(topic)
  end

  def can_publish_article(guardian:, publication:)
    guardian.can_publish_blog_topic?(publication.editable_topic)
  end

  def fetch_revision(params:, publication:)
    publication.revisions.find_by(id: params.revision_id)
  end

  def revision_is_approved(publication:, revision:)
    revision.approved_at.present? && publication.approved_revision_id == revision.id
  end

  def schedule_release(params:, guardian:, publication:, revision:)
    publication.update!(
      scheduled_revision: revision,
      scheduled_at: params.scheduled_at,
      scheduler: guardian.user,
      schedule_token: SecureRandom.uuid,
      schedule_error: "",
    )
  end

  def log_schedule(guardian:, publication:, revision:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_schedule",
      topic_id: publication.topic_id,
      revision_id: revision.id,
      scheduled_at: publication.scheduled_at,
    )
  end

  def enqueue_release(publication:)
    Jobs.enqueue_at(
      publication.scheduled_at,
      :publish_blog_revision,
      publication_id: publication.id,
      token: publication.schedule_token,
    )
  end
end

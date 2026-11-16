# frozen_string_literal: true

class Blog::Publication::Approve
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :revision_id, :integer

    validates :topic_id, :revision_id, presence: true
  end

  model :topic

  transaction do
    model :publication, :lock_publication
    policy :can_publish_article
    model :revision
    policy :revision_is_latest_submission
    only_if(:first_approval) { step :record_approver }
    step :approve_revision
    step :log_approval
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def lock_publication(topic:)
    Blog::Publication.lock_for_topic(topic)
  end

  def can_publish_article(guardian:, publication:)
    guardian.can_publish_blog_topic?(publication.editable_topic)
  end

  def fetch_revision(params:, publication:)
    publication.revisions.find_by(id: params.revision_id)
  end

  def revision_is_latest_submission(publication:, revision:)
    revision.id == publication.submitted_revision_id
  end

  def first_approval(revision:)
    revision.approved_at.nil?
  end

  def record_approver(guardian:, revision:)
    revision.update!(approver: guardian.user, approved_at: Time.current)
  end

  def approve_revision(publication:, revision:)
    publication.update!(approved_revision: revision)
  end

  def log_approval(guardian:, publication:, revision:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_approve",
      topic_id: publication.topic_id,
      revision_id: revision.id,
    )
  end
end

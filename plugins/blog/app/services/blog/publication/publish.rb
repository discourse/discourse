# frozen_string_literal: true

class Blog::Publication::Publish
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :revision_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  model :publication
  policy :can_publish_article
  policy :blog_ready, class_name: Blog::Policy::Ready

  only_if(:releasing_current_draft) do
    step :submit_current_draft
    step :approve_current_draft
  end

  transaction do
    model :publication, :lock_publication
    only_if(:releasing_revision) { model :revision }
    policy :revision_awaits_release
    model :working_copy
    policy :releasable, class_name: Blog::Publication::Policy::Releasable
    policy :not_published_as_page
    model :revision, :release_revision
    model :publication, :stage_release
    try(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved) do
      only_if(:has_discussion) { step :revise_discussion }
      only_if(:needs_discussion) { step :create_discussion }
    end
    step :save_release
    step :record_path
    step :revoke_reviews
    step :clear_schedule
    step :log_publication
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def fetch_publication(topic:)
    Blog::Publication.for_topic(topic)
  end

  def can_publish_article(guardian:, publication:)
    guardian.can_publish_blog_topic?(publication.editable_topic)
  end

  def releasing_current_draft(params:)
    params.revision_id.nil?
  end

  def submit_current_draft(params:, guardian:)
    Blog::Publication::Submit.call(params: { topic_id: params.topic_id }, guardian:) do
      on_success { |revision:| context[:revision] = revision }
      on_failure { fail!(I18n.t("invalid_access")) }
    end
  end

  def approve_current_draft(params:, guardian:, revision:)
    Blog::Publication::Approve.call(
      params: {
        topic_id: params.topic_id,
        revision_id: revision.id,
      },
      guardian:,
    ) do
      on_success { |publication:| context[:revision] = publication.approved_revision }
      on_failed_policy(:revision_is_latest_submission) { fail!(I18n.t("blog.editorial.stale")) }
      on_failure { fail!(I18n.t("invalid_access")) }
    end
  end

  def lock_publication(topic:)
    Blog::Publication.lock_for_topic(topic)
  end

  def releasing_revision(params:)
    params.revision_id.present?
  end

  def fetch_revision(params:, publication:)
    publication.revisions.find_by(id: params.revision_id)
  end

  def revision_awaits_release(publication:, revision:)
    return false if !revision.approved_at
    revision.id.in?([publication.approved_revision_id, publication.scheduled_revision_id])
  end

  def fetch_working_copy(publication:)
    publication.editorial_topic
  end

  def not_published_as_page(working_copy:)
    !PublishedPage.exists?(topic_id: working_copy.id)
  end

  def release_revision(publication:, revision:)
    publication.release_revision(revision)
  end

  def stage_release(guardian:, publication:, revision:)
    publication.stage_release(revision, guardian.user)
  end

  def has_discussion(publication:)
    publication.discussion_topic.present?
  end

  def revise_discussion(guardian:, publication:, revision:)
    post = publication.discussion_topic.first_post
    revised =
      PostRevisor.new(post).revise!(
        guardian.user,
        { raw: revision.raw, title: revision.title, tags: revision.data["tags"] },
        force_new_version: true,
      )
    raise ActiveRecord::RecordInvalid.new(post) if !revised
  end

  def needs_discussion(publication:)
    publication.discussion_topic.nil?
  end

  def create_discussion(guardian:, publication:, revision:, working_copy:)
    Blog::Publication::Action::CreateDiscussion.call(
      publication:,
      revision:,
      working_copy:,
      guardian:,
    )
  end

  def save_release(publication:)
    publication.save!
  end

  def record_path(publication:)
    publication.paths.find_or_create_by!(path: publication.path)
  end

  def revoke_reviews(working_copy:)
    Blog::Review.revoke_for_topic!(working_copy.id, by_publish: true)
  end

  def clear_schedule(publication:)
    publication.clear_schedule!
  end

  def log_publication(guardian:, publication:, revision:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_publish",
      topic_id: publication.discussion_topic_id,
      revision_id: revision.id,
    )
  end
end

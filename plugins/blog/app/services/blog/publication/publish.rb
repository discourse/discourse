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

  only_if(:releasing_revision) { model :revision }

  step :publish_revision

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
      on_failed_policy(:revision_is_latest_submission) { fail!(I18n.t("blog.editorial.stale")) }
      on_failure { fail!(I18n.t("invalid_access")) }
    end
  end

  def releasing_revision(params:)
    params.revision_id.present?
  end

  def fetch_revision(params:, publication:)
    publication.revisions.find_by(id: params.revision_id)
  end

  def publish_revision(guardian:, revision:)
    revision.publication.publish!(guardian.user, revision_id: revision.id)
  end
end

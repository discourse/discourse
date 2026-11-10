# frozen_string_literal: true

class Blog::Publication::UpdateMetadata
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :metadata

    validates :topic_id, :metadata, presence: true
  end

  model :topic
  policy :blog_ready, class_name: Blog::Policy::Ready

  transaction do
    model :publication, :stage_metadata
    policy :can_edit_article
    step :save_metadata
    step :log_metadata_change
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def stage_metadata(params:, topic:)
    Blog::Publication.lock_for_topic(topic).stage_metadata(params.metadata)
  end

  def can_edit_article(guardian:, publication:)
    guardian.can_edit_blog_topic?(publication.editable_topic)
  end

  def save_metadata(publication:)
    publication.save!
  end

  def log_metadata_change(guardian:, publication:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_metadata",
      topic_id: publication.topic_id,
      path: publication.editorial_metadata["path"],
    )
  end
end

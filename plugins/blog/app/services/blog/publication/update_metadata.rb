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
  policy :can_use_cover_upload

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

  # Upload ids are guessable, so a new cover must be the editor's own upload.
  def can_use_cover_upload(params:, topic:, guardian:)
    upload_id = params.metadata.to_h.stringify_keys["cover_upload_id"].presence
    return true if upload_id.nil?
    current = Blog::Publication.for_topic(topic).editorial_metadata["cover_upload_id"]
    upload_id.to_s == current.to_s || Upload.exists?(id: upload_id, user_id: guardian.user.id)
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

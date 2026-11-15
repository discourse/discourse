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
    Blog::Publication.lock_for_topic(topic).stage_metadata(with_co_author_ids(params.metadata))
  end

  # The editor names co-authors by username. An unknown or inactive one becomes nil,
  # which the publication rejects.
  def with_co_author_ids(metadata)
    metadata = metadata.to_h.stringify_keys
    return metadata if !metadata.key?("co_authors")
    usernames = metadata.delete("co_authors").to_s.split(",").map { User.normalize_username(_1) }
    ids = User.where(active: true, username_lower: usernames).pluck(:username_lower, :id).to_h
    metadata.merge("co_author_ids" => ids.values_at(*usernames))
  end

  # Upload ids are guessable, so a new cover must be one the editor uploaded.
  # Identical files share one upload, so a re-upload only adds a UserUpload row.
  def can_use_cover_upload(params:, topic:, guardian:)
    upload_id = params.metadata.to_h.stringify_keys["cover_upload_id"].presence
    return true if upload_id.nil? || guardian.is_admin?
    current = Blog::Publication.for_topic(topic).editorial_metadata["cover_upload_id"]
    return true if upload_id.to_s == current.to_s

    user_id = guardian.user.id
    Upload.exists?(id: upload_id, user_id:) || UserUpload.exists?(upload_id:, user_id:)
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

# frozen_string_literal: true

class Blog::Article::Find
  include Service::Base

  params do
    attribute :blog_id, :integer
    attribute :path, :string

    validates :blog_id, :path, presence: true
  end

  model :stored_path
  model :publication
  policy :requested_path_is_current

  private

  def fetch_stored_path(params:)
    Blog::Path.find_by(blog_id: params.blog_id, path: params.path)
  end

  def fetch_publication(stored_path:)
    Blog::Publication
      .publicly_visible
      .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
      .find_by(id: stored_path.publication_id)
  end

  def requested_path_is_current(params:, publication:)
    publication.path == params.path
  end
end

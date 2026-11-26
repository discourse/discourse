# frozen_string_literal: true

# Records the blog a new draft was started for, so it is listed and published
# there. A draft without a publication belongs to the default blog, so drafts
# started for it need nothing recorded.
class Blog::Publication::StartOnBlog
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :blog_id, :integer

    validates :topic_id, :blog_id, presence: true
  end

  model :topic
  policy :editorial_draft
  policy :can_edit_draft
  model :blog
  policy :blog_is_not_default
  transaction { model :publication, :create_publication }

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def editorial_draft(topic:)
    topic.blog_editorial_draft? && !Blog::Publication.where(topic_id: topic.id).exists?
  end

  def can_edit_draft(guardian:, topic:)
    guardian.can_edit_blog_topic?(topic)
  end

  def fetch_blog(params:)
    Blog::Instance.find_cached(params.blog_id)
  end

  def blog_is_not_default(blog:)
    !blog.is_default?
  end

  def create_publication(topic:, blog:)
    path = Blog::Publication.default_path(topic, blog:)
    if Blog::Path.exists?(blog_id: blog.id, path:)
      path = Blog::Publication.default_path(topic, blog:, slug: "#{topic.slug}-#{topic.id}")
    end
    Blog::Publication.create(topic:, blog:, path:)
  end
end

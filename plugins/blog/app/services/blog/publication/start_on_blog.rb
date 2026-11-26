# frozen_string_literal: true

# Records what a new draft was started as: an article on another blog, or a
# page. A draft without a publication is an article on the default blog, so
# those need nothing recorded.
class Blog::Publication::StartOnBlog
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :blog_id, :integer
    attribute :page, :boolean, default: false

    validates :topic_id, presence: true
  end

  model :topic
  policy :editorial_draft
  policy :can_edit_draft
  model :blog
  policy :differs_from_default
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
    return Blog::Instance.default_blog if params.blog_id.blank?
    Blog::Instance.find_cached(params.blog_id)
  end

  def differs_from_default(params:, blog:)
    params.page || !blog.is_default?
  end

  def create_publication(params:, topic:, blog:)
    page = params.page.present?
    path = Blog::Publication.default_path(topic, blog:, page:)
    if Blog::Path.exists?(blog_id: blog.id, path:)
      slug = "#{topic.slug}-#{topic.id}"
      path = Blog::Publication.default_path(topic, blog:, slug:, page:)
    end
    Blog::Publication.create(topic:, blog:, path:, page:)
  end
end

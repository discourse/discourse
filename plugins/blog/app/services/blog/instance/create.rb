# frozen_string_literal: true

# Adds a blog. It starts unpublished, so it can be set up before readers see it.
# Its category is created when its first article is published, as for the main blog.
class Blog::Instance::Create
  include Service::Base

  params(base_class: Blog::Instance::AttributesContract) { validates :name, :slug, presence: true }

  policy :can_manage_blogs
  policy :can_add_blog

  transaction do
    model :blog, :create_blog
    only_if(:category_chosen) { step :grant_publishers_access }
    step :log_creation
  end

  private

  def can_manage_blogs(guardian:)
    guardian.is_admin?
  end

  def can_add_blog
    Blog::Instance.addable?
  end

  def create_blog(params:)
    Blog::Instance.create(
      **params.blog_attributes,
      published: false,
      position: Blog::Instance.maximum(:position).to_i + 1,
    )
  end

  def category_chosen(blog:)
    blog.category_id.present?
  end

  def grant_publishers_access(blog:)
    Blog::AddPublishersToPublicCategory.call(params: { category_id: blog.category_id })
  end

  def log_creation(guardian:, blog:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_create",
      blog_id: blog.id,
      name: blog.name,
    )
  end
end

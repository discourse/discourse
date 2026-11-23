# frozen_string_literal: true

# Saves the fields an admin changed on one of a blog's tabs.
class Blog::Instance::Update
  include Service::Base

  params(base_class: Blog::Instance::AttributesContract) do
    attribute :blog_id, :integer
    attribute :published, :boolean

    validates :blog_id, presence: true
  end

  policy :can_manage_blogs
  model :blog

  transaction do
    model :blog, :apply_changes
    step :save_blog
    only_if(:category_changed) { step :grant_publishers_access }
    step :log_update
  end

  private

  def can_manage_blogs(guardian:)
    guardian.is_admin?
  end

  # Read from the database, not the cache, whose rows are read-only.
  def fetch_blog(params:)
    Blog::Instance.find_by(id: params.blog_id)
  end

  def apply_changes(params:, blog:)
    blog.assign_attributes(params.blog_attributes)
    blog.published = params.published if !params.published.nil?
    blog
  end

  def save_blog(blog:)
    blog.save!
  end

  def category_changed(blog:)
    blog.saved_change_to_category_id? && blog.category_id.present?
  end

  def grant_publishers_access(blog:)
    Blog::AddPublishersToPublicCategory.call(params: { category_id: blog.category_id })
  end

  def log_update(guardian:, blog:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_update",
      blog_id: blog.id,
      changes: blog.saved_changes.except("updated_at").keys.join(", "),
    )
  end
end

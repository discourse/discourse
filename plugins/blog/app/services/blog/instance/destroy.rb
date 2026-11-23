# frozen_string_literal: true

# Deletes a blog that holds no articles. Its category stays: it belongs to the admin.
class Blog::Instance::Destroy
  include Service::Base

  params do
    attribute :blog_id, :integer

    validates :blog_id, presence: true
  end

  policy :can_manage_blogs
  model :blog
  policy :not_default
  policy :no_articles

  transaction do
    step :destroy_blog
    step :log_deletion
  end

  private

  def can_manage_blogs(guardian:)
    guardian.is_admin?
  end

  def fetch_blog(params:)
    Blog::Instance.find_by(id: params.blog_id)
  end

  def not_default(blog:)
    !blog.is_default?
  end

  def no_articles(blog:)
    !Blog::Publication.where(blog_id: blog.id).exists?
  end

  def destroy_blog(blog:)
    blog.destroy!
  end

  def log_deletion(guardian:, blog:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_destroy",
      blog_id: blog.id,
      name: blog.name,
    )
  end
end

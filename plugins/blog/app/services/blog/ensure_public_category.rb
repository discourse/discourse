# frozen_string_literal: true

# Creates the public category that holds a blog's article discussions when it has
# none. Once it exists it belongs to the admin, so it is never changed here.
class Blog::EnsurePublicCategory
  include Service::Base

  params do
    attribute :blog_id, :integer

    validates :blog_id, presence: true
  end

  lock(:blog_id) do
    model :blog
    model :category, optional: true
    only_if(:category_missing) do
      policy :name_available

      transaction do
        model :category, :create_category
        step :remember_category
        step :log_category_creation
      end
    end
  end

  private

  # Read from the database, not the cache, which can lag behind a category
  # another process has just created.
  def fetch_blog(params:)
    Blog::Instance.find_by(id: params.blog_id)
  end

  def fetch_category(blog:)
    Blog::ManagedCategories.public_category(blog)
  end

  def category_missing(category:)
    category.nil?
  end

  def name_available(blog:)
    !Blog::ManagedCategories.public_category_name_taken?(blog)
  end

  def create_category(blog:)
    name = Blog::ManagedCategories.public_category_name(blog)
    Category.create(
      name:,
      slug: Blog::ManagedCategories.available_slug(name),
      description: Blog::ManagedCategories.public_category_description,
      user: Discourse.system_user,
      permissions: Blog::ManagedCategories.public_permissions,
    )
  end

  def remember_category(blog:, category:)
    blog.category_id = category.id
    blog.save!(validate: false)
  end

  def log_category_creation(category:)
    StaffActionLogger.new(Discourse.system_user).log_category_creation(category)
  end
end

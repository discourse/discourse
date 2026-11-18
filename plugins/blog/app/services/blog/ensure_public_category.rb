# frozen_string_literal: true

# Creates the public category that holds article discussions when none is chosen.
# Once it exists it belongs to the admin, so it is never changed here.
class Blog::EnsurePublicCategory
  include Service::Base

  lock(:blog_category) do
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

  def fetch_category
    Category.find_by(id: Blog::ManagedCategories.stored_category_id(:blog_category))
  end

  def category_missing(category:)
    category.nil?
  end

  def name_available
    !Blog::ManagedCategories.public_category_name_taken?
  end

  def create_category
    name = Blog::ManagedCategories.public_category_name
    Category.create(
      name:,
      slug: Blog::ManagedCategories.available_slug(name),
      description: Blog::ManagedCategories.public_category_description,
      user: Discourse.system_user,
      permissions: Blog::ManagedCategories.public_permissions,
    )
  end

  def remember_category(category:)
    SiteSetting.blog_category = category.id
  end

  def log_category_creation(category:)
    StaffActionLogger.new(Discourse.system_user).log_category_creation(category)
  end
end

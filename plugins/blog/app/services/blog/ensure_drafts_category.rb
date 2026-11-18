# frozen_string_literal: true

# Finds the private category that holds editorial drafts, creating it when it is
# missing, and keeps it readable only by the blog role groups.
class Blog::EnsureDraftsCategory
  include Service::Base

  options do
    # Role changes only repair a category that already exists.
    attribute :create_missing, :boolean, default: true
  end

  lock(:blog_drafts_category) do
    model :category, optional: true
    only_if(:category_missing) do
      policy :can_create_category

      transaction do
        model :category, :create_category
        step :remember_category
        step :log_category_creation
      end
    end
    only_if(:permissions_loosened) do
      step :restore_permissions
      step :log_permissions_repair
    end
  end

  private

  # A category the blog also uses for something else must never be made private.
  def fetch_category
    Category
      .where.not(id: [SiteSetting.blog_category.to_i, SiteSetting.shared_drafts_category.to_i])
      .find_by(id: SiteSetting.blog_drafts_category)
  end

  def category_missing(category:)
    category.nil?
  end

  def can_create_category(options:)
    options.create_missing
  end

  def create_category
    name = Blog::ManagedCategories.drafts_category_name
    Category.create(
      name:,
      slug: Blog::ManagedCategories.available_slug(name),
      user: Discourse.system_user,
      permissions: Blog::ManagedCategories.drafts_permissions,
    )
  end

  def remember_category(category:)
    SiteSetting.blog_drafts_category = category.id
  end

  def log_category_creation(category:)
    StaffActionLogger.new(Discourse.system_user).log_category_creation(category)
  end

  def permissions_loosened(category:)
    !Blog::ManagedCategories.drafts_permissions_current?(category)
  end

  def restore_permissions(category:)
    category.set_permissions(Blog::ManagedCategories.drafts_permissions)
    category.save!
  end

  def log_permissions_repair(category:)
    StaffActionLogger.new(Discourse.system_user).log_custom(
      "blog_drafts_category_permissions",
      category_id: category.id,
      permissions: category.permissions_params.to_json,
    )
  end
end

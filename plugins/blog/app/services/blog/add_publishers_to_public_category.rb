# frozen_string_literal: true

# Lets every publisher group start discussions in the public category. Only adds
# access: the category belongs to the admin, so nothing they granted is removed.
class Blog::AddPublishersToPublicCategory
  include Service::Base

  model :category
  only_if(:publishers_lack_access) do
    step :grant_publishers_access
    step :log_permissions_change
  end

  private

  def fetch_category
    Blog::ManagedCategories.public_category
  end

  # Without any group permissions, everyone can already start topics.
  def publishers_lack_access(category:)
    return if category.category_groups.empty?
    granted = category.category_groups.where(permission_type: CategoryGroup.permission_types[:full])
    (SiteSetting.blog_publisher_groups_map - granted.pluck(:group_id)).any?
  end

  def grant_publishers_access(category:)
    full = CategoryGroup.permission_types[:full]
    permissions = category.category_groups.pluck(:group_id, :permission_type).to_h
    category.set_permissions(
      permissions.merge(SiteSetting.blog_publisher_groups_map.index_with { full }),
    )
    category.save!
  end

  def log_permissions_change(category:)
    StaffActionLogger.new(Discourse.system_user).log_custom(
      "blog_category_permissions",
      category_id: category.id,
      permissions: category.permissions_params.to_json,
    )
  end
end

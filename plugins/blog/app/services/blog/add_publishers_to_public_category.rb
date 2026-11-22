# frozen_string_literal: true

# Lets every publisher group start discussions in a blog's public category. Only
# adds access: the category belongs to the admin, so nothing they granted is removed.
class Blog::AddPublishersToPublicCategory
  include Service::Base

  params do
    attribute :category_id, :integer

    validates :category_id, presence: true
  end

  model :category
  only_if(:publishers_lack_access) do
    step :grant_publishers_access
    step :log_permissions_change
  end

  private

  def fetch_category(params:)
    Category.find_by(id: params.category_id)
  end

  # Without any group permissions, everyone can already start topics.
  def publishers_lack_access(category:)
    return if category.category_groups.empty?
    granted = category.category_groups.where(permission_type: CategoryGroup.permission_types[:full])
    (Blog::ManagedCategories.publisher_group_ids - granted.pluck(:group_id)).any?
  end

  def grant_publishers_access(category:)
    full = CategoryGroup.permission_types[:full]
    permissions = category.category_groups.pluck(:group_id, :permission_type).to_h
    category.set_permissions(
      permissions.merge(Blog::ManagedCategories.publisher_group_ids.index_with { full }),
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

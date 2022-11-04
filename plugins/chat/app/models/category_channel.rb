# frozen_string_literal: true

class CategoryChannel < ChatChannel
  alias_attribute :category, :chatable

  delegate :read_restricted?, to: :category
  delegate :url, to: :chatable, prefix: true

  %i[category_channel? public_channel? chatable_has_custom_fields?].each do |name|
    define_method(name) { true }
  end

  def allowed_group_ids
    return if !read_restricted?

    staff_groups = Group::AUTO_GROUPS.slice(:staff, :moderators, :admins).values
    category.secure_group_ids.to_a.concat(staff_groups)
  end

  def title(_ = nil)
    name.presence || category.name
  end

  def slug
    title.truncate(100).parameterize
  end
end

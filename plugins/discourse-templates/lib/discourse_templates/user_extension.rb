# frozen_string_literal: true

module DiscourseTemplates::UserExtension
  def can_use_templates?
    can_use_category_templates? || can_use_private_templates?
  end

  def can_use_category_templates?
    return false if SiteSetting.discourse_templates_categories.blank?

    parent_categories_ids = SiteSetting.discourse_templates_categories&.split("|")&.map(&:to_i)

    parent_categories_ids.any? do |category_id|
      return false if category_id == 0

      category = Category.find_by(id: category_id)
      return false if category.blank?

      # the user can use templates if can see topics in at least one of the source categories
      guardian.can_see?(category)
    end
  end

  def can_use_private_templates?
    return false unless SiteSetting.discourse_templates_enable_private_templates
    return false unless SiteSetting.tagging_enabled
    return false if SiteSetting.discourse_templates_private_templates_tags.blank?

    in_any_groups?(SiteSetting.discourse_templates_groups_allowed_private_templates_map)
  end
end

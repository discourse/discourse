# frozen_string_literal: true

module DiscourseAssignSpecHelpers
  def allow_group_to_assign_in_category(category, group)
    category.custom_fields[
      DiscourseAssign::AssignmentPermissions::CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS
    ] = group.id.to_s
    category.save_custom_fields
  end
end

RSpec.configure { |config| config.include DiscourseAssignSpecHelpers }

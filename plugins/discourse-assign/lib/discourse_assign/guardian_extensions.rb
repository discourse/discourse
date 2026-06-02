# frozen_string_literal: true

module DiscourseAssign
  module GuardianExtensions
    def can_assign?(target = nil)
      return false if user.blank?
      return can_assign_target?(target) if target

      return @can_assign if defined?(@can_assign)

      @can_assign = can_assign_globally? || scoped_assign_group_ids_for_user.present?
    end

    def can_assign_globally?
      return false if user.blank?
      return @can_assign_globally if defined?(@can_assign_globally)

      @can_assign_globally =
        if user.admin?
          true
        else
          allowed_group_ids = DiscourseAssign::AssignmentPermissions.global_group_ids
          allowed_group_ids.present? && (allowed_group_ids & user.group_ids).present?
        end
    end

    private

    def can_assign_target?(target)
      return true if can_assign_globally?

      category_id = DiscourseAssign::AssignmentPermissions.category_id_for(target)
      return false if category_id.blank?

      (
        DiscourseAssign::AssignmentPermissions.scoped_group_ids_for_category(category_id) &
          user.group_ids
      ).present?
    end

    def scoped_assign_group_ids_for_user
      DiscourseAssign::AssignmentPermissions.scoped_group_ids_for_user(user)
    end
  end
end

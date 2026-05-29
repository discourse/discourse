# frozen_string_literal: true

module DiscourseAssign
  module AssignmentPermissions
    CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS = "additional_assign_allowed_on_groups"

    class << self
      def can_assign_anywhere?(user)
        return false if user.blank?

        can_assign_globally?(user) || scoped_group_ids_for_user(user).present?
      end

      def can_assign_target?(user, target)
        return false if user.blank?
        return true if can_assign_globally?(user)

        category_id = category_id_for(target)
        return false if category_id.blank?

        (scoped_group_ids_for_category(category_id) & group_ids_for(user)).present?
      end

      def can_assign_globally?(user)
        return false if user.blank?
        return true if user.admin?

        allowed_group_ids = global_group_ids
        allowed_group_ids.present? && (allowed_group_ids & group_ids_for(user)).present?
      end

      def allowed_user_ids_for_target(target)
        ids = Set.new(admin_user_ids)
        ids.merge(user_ids_in_groups(global_group_ids))
        ids.merge(user_ids_in_groups(scoped_group_ids_for_category(category_id_for(target))))
        ids.to_a
      end

      def allowed_group_ids_for_target(user, target)
        ids = Set.new(Group.assignable(user).pluck(:id))
        ids.merge(scoped_group_ids_for_category(category_id_for(target)))
        ids.to_a
      end

      def assign_allowed_groups_for_target(target)
        Group.where(id: global_group_ids | scoped_group_ids_for_category(category_id_for(target)))
      end

      def assign_allowed_groups_for_user(user)
        group_ids =
          if can_assign_globally?(user)
            global_group_ids | all_scoped_group_ids
          else
            global_group_ids | scoped_group_ids_for_user(user)
          end

        Group.where(id: group_ids)
      end

      def assignable_user_ids_for_user(user)
        group_ids =
          if can_assign_globally?(user)
            global_group_ids | all_scoped_group_ids
          else
            global_group_ids | scoped_group_ids_for_user(user)
          end

        (admin_user_ids | user_ids_in_groups(group_ids)).uniq
      end

      def all_assign_allowed_group_ids
        global_group_ids | all_scoped_group_ids
      end

      def category_id_for(target)
        case target
        when Topic
          target.category_id
        when Post
          target.topic&.category_id
        else
          nil
        end
      end

      private

      def global_group_ids
        SiteSetting.assign_allowed_on_groups_map
      end

      def all_scoped_group_ids
        CategoryCustomField
          .where(name: CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS)
          .pluck(:value)
          .flat_map { |value| group_ids_from_value(value) }
          .uniq
      end

      def scoped_group_ids_for_user(user)
        all_scoped_group_ids & group_ids_for(user)
      end

      def scoped_group_ids_for_category(category_id)
        return [] if category_id.blank?

        group_ids_from_value(
          CategoryCustomField.where(
            category_id:,
            name: CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS,
          ).pick(:value),
        )
      end

      def group_ids_for(user)
        user.group_ids
      end

      def admin_user_ids
        User.where(admin: true).pluck(:id)
      end

      def user_ids_in_groups(group_ids)
        return [] if group_ids.blank?

        GroupUser.where(group_id: group_ids).pluck(:user_id)
      end

      def group_ids_from_value(value)
        value.to_s.split("|").map(&:to_i).reject(&:zero?)
      end
    end
  end
end

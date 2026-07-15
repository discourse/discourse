# frozen_string_literal: true
module Acl
  # This class is used to provide easy lookup methods for
  # a single target's flattened ACL list, which consists
  # of a mix of group and user IDs and their associated permissions,
  # as an alternative to iterating through the flattened array.
  class Target
    attr_reader :group_lookup, :permission_lookup, :user_lookup

    def initialize(flattened_acl_list)
      @group_lookup = {}
      @user_lookup = {}
      @permission_lookup = {}

      flattened_acl_list.each do |acl|
        @permission_lookup[acl[:permission]] ||= { group_ids: [], user_ids: [] }

        if acl[:type].to_sym == :group
          @group_lookup[acl[:id]] ||= []
          @group_lookup[acl[:id]] << acl[:permission]

          @permission_lookup[acl[:permission]][:group_ids] << acl[:id]
        end

        if acl[:type].to_sym == :user
          @user_lookup[acl[:id]] ||= []
          @user_lookup[acl[:id]] << acl[:permission]

          @permission_lookup[acl[:permission]][:user_ids] << acl[:id]
        end
      end
    end

    def group_has_permission?(group_or_id, permission)
      @group_lookup[group_or_id.is_a?(Numeric) ? group_or_id : group_or_id&.id]&.include?(
        permission,
      )
    end

    def group_has_any_permission?(group_or_id, permissions)
      group_permissions = @group_lookup[group_or_id.is_a?(Numeric) ? group_or_id : group_or_id&.id]
      (group_permissions || []).any? { |permission| permissions.include?(permission) }
    end

    def permission_group_ids(permission)
      ((@permission_lookup[permission] || {}).dig(:group_ids) || []).dup
    end

    def group_ids_with_any_permission(permissions)
      permissions.flat_map { |permission| permission_group_ids(permission) || [] }.uniq.dup
    end

    def user_has_permission?(user_or_id, permission)
      @user_lookup[user_or_id.is_a?(Numeric) ? user_or_id : user_or_id&.id]&.include?(permission)
    end

    def user_has_any_permission?(user_or_id, permissions)
      user_permissions = @user_lookup[user_or_id.is_a?(Numeric) ? user_or_id : user_or_id&.id]
      (user_permissions || []).any? { |permission| permissions.include?(permission) }
    end

    def permission_user_ids(permission)
      ((@permission_lookup[permission] || {}).dig(:user_ids) || []).dup
    end

    def user_ids_with_any_permission(permissions)
      permissions.flat_map { |permission| permission_user_ids(permission) || [] }.uniq.dup
    end
  end
end

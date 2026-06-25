# frozen_string_literal: true
module Acl
  class Target
    attr_reader :group_lookup, :permission_lookup

    def initialize(flattened_acl_list)
      @group_lookup = {}
      @permission_lookup = {}

      flattened_acl_list.each do |acl|
        @permission_lookup[acl[:permission]] ||= { group_ids: [] }

        if acl[:type].to_sym == :group
          @group_lookup[acl[:id]] ||= []
          @group_lookup[acl[:id]] << acl[:permission]

          # TODO (martin) Handle users here too in a followup PR when we allow adding them in the UI.
          @permission_lookup[acl[:permission]][:group_ids] << acl[:id]
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
  end
end

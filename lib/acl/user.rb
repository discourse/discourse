# frozen_string_literal: true

module Acl
  # This class is used to provide easy lookup methods for a single user's
  # flattened ACL list, which can consist of multiple different targets, as an
  # alternative to iterating through the flattened array.
  class User
    attr_reader :target_lookup, :permission_lookup

    def initialize(flattened_acl_list)
      @target_lookup = {}
      @permission_lookup = {}

      flattened_acl_list.each do |acl|
        @target_lookup[target_key(acl)] ||= []
        @target_lookup[target_key(acl)] << acl[:permission]

        @permission_lookup[acl[:permission]] ||= {}
        @permission_lookup[acl[:permission]][acl[:target_type]] ||= []
        @permission_lookup[acl[:permission]][acl[:target_type]] << acl[:target_id]
      end
    end

    def has_target_permission?(target, permission)
      @target_lookup[target_key(target)]&.include?(permission)
    end

    def has_any_target_permission?(target, permissions)
      target_permissions = @target_lookup[target_key(target)]
      (target_permissions || []).any? { |permission| permissions.include?(permission) }
    end

    def target_ids_with_permission(target_class, permission)
      ((@permission_lookup[permission] || {}).dig(target_class.polymorphic_name) || []).dup
    end

    def target_ids_with_any_permissions(target_class, permissions)
      permissions
        .flat_map { |permission| target_ids_with_permission(target_class, permission) }
        .uniq
        .dup
    end

    private

    def target_key(target)
      if target.is_a?(Hash)
        "#{target[:target_type]}_#{target[:target_id]}"
      else
        "#{target.class.polymorphic_name}_#{target.id}"
      end
    end
  end
end

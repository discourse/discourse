# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    # Workflow ACL fields store fixed grants alongside a group-ID expression and
    # a shared permission. Services need a flattened list of individual grants.
    # This service resolves only the group input, validates its runtime value,
    # and merges it with the literal grants, which take precedence. Authorization
    # and persistence remain the responsibility of the resource's write service.
    #
    # Saved configuration (with view/edit/manage allowed):
    #   {
    #     entries: [{ type: "group", id: 12, permission: "manage" }],
    #     group_ids: "={{ $json.group_ids }}",
    #     permission: "edit"
    #   }
    # Workflow input: { "group_ids" => [12, 34, 56] }
    # Returned ACL (the fixed grant for group 12 takes precedence):
    #   [
    #     { type: "group", id: 12, permission: "manage" },
    #     { type: "group", id: 34, permission: "edit" },
    #     { type: "group", id: 56, permission: "edit" }
    #   ]
    class AccessControlParameter
      include Service::Base

      params do
        attribute :value

        def configuration
          (value.is_a?(Hash) ? value : { entries: value }).with_indifferent_access
        end
      end

      options do
        attribute :required_permissions
        attribute :acl_target_type
      end

      model :input_group_ids, :resolve_input_groups, optional: true
      policy :valid_group_ids
      policy :groups_exist
      model :acl, :merge_grants, optional: true
      policy :required_permissions_present

      private

      def resolve_input_groups(params:, resolver:)
        input = params.configuration[:group_ids]
        input.nil? || input == "" ? [] : resolver.resolve(input)
      end

      def valid_group_ids(input_group_ids:)
        input_group_ids.is_a?(Array) && input_group_ids.all? { |id| id.is_a?(Integer) && id >= 0 }
      end

      def groups_exist(input_group_ids:)
        Group.where(id: input_group_ids, automatic: false).count == input_group_ids.uniq.size
      end

      def merge_grants(params:, input_group_ids:)
        configuration = params.configuration
        entries = AccessControlList.dedup_flattened_list(configuration[:entries])
        fixed_group_ids = entries.select { |entry| entry[:type] == "group" }.pluck(:id)
        entries +
          (input_group_ids.uniq - fixed_group_ids).map do |id|
            {
              type: "group",
              id: id,
              permission: configuration[:permission],
            }.with_indifferent_access
          end
      end

      def required_permissions_present(acl:, options:)
        return true if options.required_permissions.blank?

        effective_acl =
          if options.acl_target_type.present?
            AccessControlList.inject_mandatory_acl(acl, options.acl_target_type)
          else
            acl
          end
        effective_acl.any? do |entry|
          options.required_permissions.include?(entry[:permission].to_s)
        end
      end
    end
  end
end

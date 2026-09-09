# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    # TODO (martin) Investigate this, looks pretty ew, used in ParameterResolver,
    # feels very "bespoke"
    class AccessControlParameter
      def initialize(schema:, resolver:)
        @options = schema.with_indifferent_access.fetch(:control_options, {})
        @resolver = resolver
      end

      def resolve(value)
        config = value.is_a?(Hash) ? value.with_indifferent_access : { entries: value }
        entries = normalize_entries(config[:entries])

        unless config[:group_ids].nil? || config[:group_ids] == ""
          permission = config[:permission]
          fail!(:invalid_permission) if permissions.exclude?(permission)
          group_ids = @resolver.resolve(config[:group_ids])
          unless group_ids.is_a?(Array) && group_ids.all? { |id| id.is_a?(Integer) && id >= 0 }
            fail!(:invalid_groups)
          end
          group_ids = group_ids.uniq
          fail!(:missing_groups) if Group.where(id: group_ids).count != group_ids.size

          fixed_group_ids = entries.select { |entry| entry[:type] == "group" }.pluck(:id)
          entries +=
            (group_ids - fixed_group_ids).map do |id|
              { type: "group", id: id, permission: permission }.with_indifferent_access
            end
        end

        required = @options[:required_permissions]
        if required.present?
          effective_entries =
            (
              if @options[:acl_target_type].present?
                AccessControlList.inject_mandatory_acl(entries, @options[:acl_target_type])
              else
                entries
              end
            )
          unless effective_entries.any? { |entry| required.include?(entry[:permission].to_s) }
            fail!(:required_permission, permissions: required.join(", "))
          end
        end
        entries
      end

      private

      def permissions
        @options[:permissions] || %w[view edit]
      end

      def normalize_entries(entries)
        fail!(:invalid_entries) unless entries.is_a?(Array)
        entries
          .map do |entry|
            fail!(:invalid_entries) unless entry.is_a?(Hash)
            entry = entry.with_indifferent_access
            valid =
              %w[group user].include?(entry[:type]) && entry[:id].is_a?(Integer) &&
                (entry[:type] == "user" || entry[:id] >= 0) &&
                permissions.include?(entry[:permission])
            fail!(:invalid_entries) unless valid
            entry
          end
          .uniq { |entry| [entry[:type], entry[:id], entry[:permission]] }
      end

      def fail!(key, **options)
        raise NodeError, I18n.t("discourse_workflows.errors.access_control.#{key}", **options)
      end
    end
  end
end

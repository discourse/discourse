# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    model :node_types
    model :credential_types
    model :expression_context

    private

    def fetch_node_types(guardian:)
      DiscourseWorkflows::Registry
        .nodes
        .uniq(&:identifier)
        .filter_map do |klass|
          identifier = klass.identifier
          next unless klass.palette_visible?

          NodeTypeSerializer.new(
            identifier: identifier,
            available_versions: Registry.available_versions(identifier),
            guardian: guardian,
          ).to_h
        end
    end

    def fetch_credential_types
      DiscourseWorkflows::Registry.credential_types.map do |klass|
        {
          identifier: klass.identifier,
          display_name: klass.display_name,
          property_schema: klass.property_schema,
        }
      end
    end

    def fetch_expression_context
      DiscourseWorkflows::ExpressionContextSchema.to_hash
    end
  end
end

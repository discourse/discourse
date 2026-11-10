# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::ResolveOutputSchemas
    include Service::Base

    params do
      attribute :nodes
      attribute :connections

      validates :nodes, presence: true, length: { maximum: WorkflowGraphValidator::MAX_NODES }
      validate :nodes_are_hashes
      validate :connections_is_a_hash

      private

      def nodes_are_hashes
        errors.add(:nodes, :invalid) unless nodes.is_a?(Array) && nodes.all?(Hash)
      end

      def connections_is_a_hash
        errors.add(:connections, :invalid) unless connections.nil? || connections.is_a?(Hash)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    try(Schema::GraphResolver::NotConverged) { step :resolve }

    private

    def resolve(params:)
      context[:output_schemas] = Schema.resolve_graph(
        params.nodes.map(&:deep_stringify_keys),
        params.connections.to_h.deep_stringify_keys,
      )[
        :output_schemas
      ]
    end
  end
end

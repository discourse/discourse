# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class NodeProxyProvider
      ALLOWED_NODE_IDENTIFIERS = %w[action:data_table].freeze

      def initialize(node_identifier:, data_table_access_validator: nil, guardian: nil)
        @node_identifier = node_identifier.to_s
        @data_table_access_validator = data_table_access_validator
        @guardian = guardian
      end

      def get_data_table_proxy(data_table_id)
        validate_request!
        ensure_can_manage_workflows!
        data_table_id = data_table_id.to_s
        @data_table_access_validator&.call(data_table_id)
        data_table = DiscourseWorkflows::DataTable.find(data_table_id)

        NodeProxy.new(Facade.new(data_table))
      end

      def get_data_table_aggregate_proxy
        validate_request!
        ensure_can_manage_workflows!

        AggregateNodeProxy.new
      end

      private

      def validate_request!
        return if ALLOWED_NODE_IDENTIFIERS.include?(@node_identifier)

        raise Discourse::InvalidAccess
      end

      def ensure_can_manage_workflows!
        return if @guardian.nil? || @guardian.can_manage_workflows?

        raise Discourse::InvalidAccess
      end
    end
  end
end

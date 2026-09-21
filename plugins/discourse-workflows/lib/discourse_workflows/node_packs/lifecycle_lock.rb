# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    module LifecycleLock
      IDENTIFIER_PATTERN = /\Aaction:([a-z][a-z0-9_]{1,31})\.[a-z][a-z0-9_]{1,39}\z/
      MissingReferencesError =
        Class.new(StandardError) do
          attr_reader :references

          def initialize(references)
            @references = references
            super("Workflow references unavailable imported node definitions")
          end
        end

      module_function

      def with_graph_write(nodes)
        ActiveRecord::Base.transaction do
          lock_nodes!(nodes)
          missing = missing_references(nodes)
          raise MissingReferencesError.new(missing) if missing.any?

          yield
        end
      end

      def with_node_locks(nodes, &block)
        ActiveRecord::Base.transaction do
          lock_nodes!(nodes)
          block.call
        end
      end

      def missing_reference_messages(references)
        references.map do |reference|
          I18n.t(
            "discourse_workflows.errors.unsupported_node_version",
            version: reference[:version],
            type: reference[:identifier],
          )
        end
      end

      def lock_keys!(keys)
        keys = keys.compact.uniq.sort
        return if keys.empty?

        unless ActiveRecord::Base.connection.transaction_open?
          raise "Node pack lifecycle locks require a database transaction"
        end

        keys.each do |key|
          DB.exec(
            "SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))",
            key: "discourse-workflows:node-pack:#{key}",
          )
        end
      end

      def lock_nodes!(nodes)
        lock_keys!(pack_references(nodes).map { |reference| reference[:pack_key] })
      end

      def missing_references(nodes)
        references = pack_references(nodes)
        return [] if references.empty?

        identifiers = references.map { |reference| reference[:identifier] }.uniq
        installed =
          NodePackDefinition
            .joins(:node_pack)
            .merge(NodePack.installed)
            .where(identifier: identifiers)
            .pluck(:identifier, :version)
            .to_set

        references.reject do |reference|
          reference[:version].present? &&
            installed.include?([reference[:identifier], reference[:version]])
        end
      end

      def installed_references?(nodes)
        missing_references(nodes).empty?
      end

      def pack_references(nodes)
        Array(nodes).filter_map do |node|
          if node.is_a?(Hash)
            identifier = node[:type] || node["type"]
            version = node[:typeVersion] || node["typeVersion"]
          else
            identifier = node.type
            version = node.type_version
          end
          match = IDENTIFIER_PATTERN.match(identifier.to_s)
          next unless match

          { pack_key: match[1], identifier:, version: }
        end
      end
    end
  end
end

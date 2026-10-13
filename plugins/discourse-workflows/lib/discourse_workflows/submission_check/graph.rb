# frozen_string_literal: true

module DiscourseWorkflows
  module SubmissionCheck
    class Graph
      class Invalid < StandardError
      end

      TRIGGER = "trigger:before_post_submission"
      REJECT = "action:reject_submission"
      IF = "condition:if"
      NOTE = "flow:sticky_note"
      MAX_NODES = 20
      MAX_CONDITIONS = 10
      MAX_MESSAGE_LENGTH = 500

      attr_reader :trigger, :edges

      def initialize(nodes:, connections:, settings: {}, error_workflow_id: nil)
        @nodes = nodes
        @connections = connections
        @settings = settings
        @error_workflow_id = error_workflow_id
      end

      def self.restricted?(nodes)
        Array(nodes).any? { |node| [TRIGGER, REJECT].include?(node["type"] || node[:type]) }
      end

      def self.inert_direct_settings?(node)
        NodeData
          .direct_settings(node)
          .all? do |key, value|
            case key
            when "notes"
              value == ""
            when "notesInFlow", "alwaysOutputData"
              value == false
            else
              false
            end
          end
      end

      def validate_draft!
        raise Invalid unless @nodes.is_a?(Array) && @nodes.size <= MAX_NODES
        unless @nodes.all? { |node| node.is_a?(Hash) && self.class.inert_direct_settings?(node) }
          raise Invalid
        end
        unless @nodes.all? { |node|
                 type = node["type"] || node[:type]
                 version = node["typeVersion"] || node[:typeVersion]
                 [TRIGGER, IF, REJECT, NOTE].include?(type) && version == "1.0"
               }
          raise Invalid
        end
        self
      end

      def validate_draft_connections!
        raise Invalid unless @connections.is_a?(Hash)

        names = @nodes.map { |node| node["name"] || node[:name] }.to_set
        @connections.each do |source, outputs|
          raise Invalid unless names.include?(source.to_s) && outputs.is_a?(Hash)

          outputs.each_value do |slots|
            raise Invalid unless slots.is_a?(Array)
            slots.each do |targets|
              raise Invalid unless targets.is_a?(Array)
              targets.each do |target|
                raise Invalid unless target.is_a?(Hash)
                raise Invalid if names.exclude?(target["node"] || target[:node])
              end
            end
          end
        end
        self
      end

      def self.validate_scope!(parameters)
        raise Invalid unless parameters.is_a?(Hash)
        raise Invalid unless (parameters.keys - %w[category_ids include_subcategories]).empty?
        ids = parameters.fetch("category_ids", [])
        unless ids.is_a?(Array) && ids.size.between?(1, 20) &&
                 ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
          raise Invalid
        end
        raise Invalid if [true, false].exclude?(parameters.fetch("include_subcategories", true))
        parameters
      end

      def validate!
        raise Invalid unless @nodes.is_a?(Array) && @nodes.size.between?(1, MAX_NODES)
        raise Invalid unless @connections.is_a?(Hash) && valid_settings? && @error_workflow_id.nil?
        raise Invalid unless @nodes.all? { |node| node.is_a?(Hash) }

        @nodes = @nodes.map(&:deep_stringify_keys)
        @nodes_by_name = @nodes.index_by { |node| node["name"] }
        raise Invalid unless @nodes_by_name.size == @nodes.size
        raise Invalid if @nodes.any? { |node| node["name"].blank? || node["id"].blank? }
        raise Invalid unless @nodes.map { |node| node["id"] }.uniq.size == @nodes.size
        raise Invalid unless @nodes.count { |node| node["type"] == TRIGGER } == 1
        raise Invalid unless @nodes.any? { |node| node["type"] == REJECT }

        @nodes.each { |node| validate_node!(node) }
        @trigger = @nodes.find { |node| node["type"] == TRIGGER }
        validate_connections!
        visit!(@trigger["name"], Set.new, Set.new)
        raise Invalid unless @visited.size == @nodes.count { |node| node["type"] != NOTE }
        self
      end

      def node(name)
        @nodes_by_name.fetch(name)
      end

      private

      def valid_settings?
        @settings.is_a?(Hash) && (@settings.keys - ["timezone"]).empty? &&
          (@settings["timezone"].blank? || WorkflowTimezone.valid?(@settings["timezone"]))
      end

      def validate_node!(node)
        type = node["type"]
        raise Invalid if [TRIGGER, IF, REJECT, NOTE].exclude?(type)
        raise Invalid unless node["typeVersion"] == "1.0"
        raise Invalid if node.fetch("credentials", {}).present?
        raise Invalid if node["webhookId"].present?
        raise Invalid if !self.class.inert_direct_settings?(node)

        params = node.fetch("parameters", {})
        raise Invalid unless params.is_a?(Hash)
        case type
        when TRIGGER
          self.class.validate_scope!(params)
        when IF
          raise Invalid unless (params.keys - %w[conditions combinator options]).empty?
          conditions = params["conditions"]
          unless conditions.is_a?(Array) && conditions.size.between?(1, MAX_CONDITIONS)
            raise Invalid
          end
          raise Invalid if %w[and or].exclude?(params.fetch("combinator", "and"))
          options = params.fetch("options", {})
          raise Invalid unless options.is_a?(Hash) && (options.keys - ["caseSensitive"]).empty?
          raise Invalid if [true, false].exclude?(options.fetch("caseSensitive", true))
          conditions.each { |condition| validate_condition!(condition) }
        when REJECT
          raise Invalid unless params.keys == ["message"]
          message = params["message"]
          unless message.is_a?(String) && message.strip.present? &&
                   message.length <= MAX_MESSAGE_LENGTH
            raise Invalid
          end
          raise Invalid if message.start_with?("=") || message.match?(/[\x00-\x1f\x7f]/)
        end
      end

      def validate_condition!(condition)
        raise Invalid unless condition.is_a?(Hash)
        raise Invalid unless (condition.keys - %w[id operator leftValue rightValue]).empty?
        operator = condition["operator"]
        unless operator.is_a?(Hash) && (operator.keys - %w[type operation singleValue]).empty?
          raise Invalid
        end
        type = operator["type"]
        operation = operator["operation"]
        raise Invalid unless Executor::FilterParameter.supported_operation?(type, operation)
        %w[leftValue rightValue].each do |key|
          value = condition[key]
          raise Invalid unless value.is_a?(String) && value.length <= 500
        end
      end

      def validate_connections!
        @edges = Hash.new { |hash, name| hash[name] = [[], []] }
        @connections.each do |source, outputs|
          source_node = @nodes_by_name[source.to_s]
          raise Invalid unless source_node && [TRIGGER, IF].include?(source_node["type"])
          raise Invalid unless outputs.is_a?(Hash) && outputs.keys == ["main"]
          slots = outputs["main"]
          expected = source_node["type"] == IF ? 2 : 1
          raise Invalid unless slots.is_a?(Array) && slots.size.between?(1, expected)
          slots.each_with_index do |targets, slot|
            raise Invalid unless targets.is_a?(Array) && targets.size <= MAX_NODES
            targets.each do |target|
              raise Invalid unless target.is_a?(Hash)
              target = target.deep_stringify_keys
              raise Invalid unless target.keys.sort == %w[index node type]
              dest = @nodes_by_name[target["node"]]
              raise Invalid unless dest && [IF, REJECT].include?(dest["type"])
              raise Invalid unless target["index"] == 0 && target["type"] == "main"
              @edges[source.to_s][slot] << dest["name"]
            end
          end
        end
        raise Invalid if @edges.values.sum { |slots| slots.sum(&:size) } > MAX_NODES * 2
      end

      def visit!(name, active, visited)
        raise Invalid if active.include?(name)
        return if visited.include?(name)

        active.add(name)
        @edges[name].flatten.each { |destination| visit!(destination, active, visited) }
        active.delete(name)
        visited.add(name)
        @visited = visited
      end
    end
  end
end

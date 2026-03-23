# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    class Base
      def self.identifier
        raise NotImplementedError
      end

      def self.configuration_schema
        {}
      end

      def self.branching?
        false
      end

      def initialize(configuration: {})
        @configuration = configuration
      end

      def execute(context, input_items:, node_context:)
        input_items.map do |item|
          resolver = ExpressionResolver.new(context.merge("$json" => item["json"]))
          resolved_config = resolver.resolve_hash(@configuration.deep_stringify_keys)
          result = execute_single(context, item: item, config: resolved_config)
          { "json" => result.deep_stringify_keys }
        end
      end

      def execute_single(context, item:, config:)
        raise NotImplementedError
      end

      private

      def resolve_author(user_id)
        user_id.present? ? User.find(user_id) : Discourse.system_user
      end

      def resolve_config_with_items(context, input_items)
        item_json = input_items.first&.dig("json") || {}
        resolver = ExpressionResolver.new(context.merge("$json" => item_json))
        resolver.resolve_hash(@configuration.deep_stringify_keys)
      end
    end
  end
end

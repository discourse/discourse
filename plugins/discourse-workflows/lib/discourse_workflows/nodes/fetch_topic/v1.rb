# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FetchTopic
      class V1 < NodeType
        def self.identifier
          "action:fetch_topic"
        end

        def self.icon
          "download"
        end

        def self.color
          "light-blue"
        end

        def self.group
          "discourse_actions"
        end

        def self.property_schema
          { topic_id: { type: :string, required: true } }
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(config)
              Item.new(result).to_h
            end
          ItemContract.validate_items!(items, source: self.class.identifier)
          [items]
        end

        private

        def process(config)
          topic = Topic.find(config["topic_id"])
          { topic: Schemas::Topic.resolve(topic) }
        end
      end
    end
  end
end

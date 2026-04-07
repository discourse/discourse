# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ListTopics
      class V1 < NodeType
        MAX_LIMIT = 100
        DEFAULT_LIMIT = 30

        def self.identifier
          "action:list_topics"
        end

        def self.icon
          "list"
        end

        def self.color_key
          "light-blue"
        end

        def self.group
          "discourse_actions"
        end

        def self.configuration_schema
          {
            query: {
              type: :string,
              required: true,
              ui: {
                control: :filter_query,
              },
            },
            limit: {
              type: :integer,
              required: false,
              default: DEFAULT_LIMIT,
            },
          }
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.with_item(item) { exec_ctx.resolve_config(@configuration) }

          query = config["query"]
          limit = [[Integer(config.fetch("limit") { DEFAULT_LIMIT }), 1].max, MAX_LIMIT].min

          topic_query = TopicQuery.new(exec_ctx.run_as_user, q: query, per_page: limit)
          topic_list = topic_query.list_filter

          items =
            topic_list.topics.map { |topic| Item.new(topic: Schemas::Topic.resolve(topic)).to_h }
          [items]
        end
      end
    end
  end
end

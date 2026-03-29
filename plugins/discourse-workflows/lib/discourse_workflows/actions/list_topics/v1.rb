# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module ListTopics
      class V1 < Actions::Base
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
          Schemas::Topic.fields
        end

        def execute(context, input_items:, node_context:, user: nil)
          config = resolve_config_with_items(context, input_items)
          query = config["query"]
          limit = [[(config["limit"] || DEFAULT_LIMIT).to_i, 1].max, MAX_LIMIT].min

          topic_query = TopicQuery.new(Discourse.system_user, q: query, per_page: limit)
          topic_list = topic_query.list_filter

          topic_list.topics.map do |topic|
            { "json" => Schemas::Topic.resolve(topic).deep_stringify_keys }
          end
        end
      end
    end
  end
end

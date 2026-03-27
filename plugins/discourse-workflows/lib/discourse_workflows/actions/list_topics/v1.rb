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
          {
            topic_id: :integer,
            title: :string,
            category_id: :integer,
            tags: :array,
            username: :string,
            created_at: :string,
            bumped_at: :string,
            posts_count: :integer,
            views: :integer,
            like_count: :integer,
            status: :string,
          }
        end

        def execute(context, input_items:, node_context:, user: nil)
          config = resolve_config_with_items(context, input_items)
          query = config["query"]
          limit = [[(config["limit"] || DEFAULT_LIMIT).to_i, 1].max, MAX_LIMIT].min

          topic_query = TopicQuery.new(Discourse.system_user, q: query, per_page: limit)
          topic_list = topic_query.list_filter

          topic_list.topics.map do |topic|
            {
              "json" => {
                "topic_id" => topic.id,
                "title" => topic.title,
                "category_id" => topic.category_id,
                "tags" => topic.tags.pluck(:name),
                "username" => topic.user&.username,
                "created_at" => topic.created_at&.iso8601,
                "bumped_at" => topic.bumped_at&.iso8601,
                "posts_count" => topic.posts_count,
                "views" => topic.views,
                "like_count" => topic.like_count,
                "status" => topic_status(topic),
              },
            }
          end
        end

        private

        def topic_status(topic)
          if topic.archived
            "archived"
          elsif topic.closed
            "closed"
          else
            "open"
          end
        end
      end
    end
  end
end

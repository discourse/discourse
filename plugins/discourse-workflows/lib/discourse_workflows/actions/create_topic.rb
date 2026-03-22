# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    class CreateTopic < Base
      def self.identifier
        "action:create_topic"
      end

      def self.configuration_schema
        {
          title: {
            type: :string,
            required: true,
          },
          raw: {
            type: :string,
            required: true,
            ui: {
              control: :textarea,
              rows: 8,
            },
          },
          category_id: {
            type: :integer,
            required: false,
          },
          tag_names: {
            type: :string,
            required: false,
          },
          user_id: {
            type: :integer,
            required: false,
          },
        }
      end

      def self.output_schema
        {
          topic_id: :integer,
          topic_title: :string,
          topic_raw: :string,
          tags: :array,
          category_id: :integer,
          user_id: :integer,
          username: :string,
          archetype: :string,
          post_id: :integer,
          post_number: :integer,
        }
      end

      def execute_single(_context, item:, config:)
        author = resolve_author(config["user_id"])
        post = PostCreator.new(author, build_post_args(config)).create!
        topic = post.topic

        {
          topic_id: topic.id,
          topic_title: topic.title,
          topic_raw: post.raw,
          tags: topic.tags.pluck(:name),
          category_id: topic.category_id,
          user_id: topic.user_id,
          username: topic.user&.username,
          archetype: topic.archetype,
          post_id: post.id,
          post_number: post.post_number,
        }
      end

      private

      def build_post_args(config)
        args = { title: config["title"], raw: config["raw"], skip_workflows: true }

        args[:category] = config["category_id"] if config["category_id"].present?

        tag_names = normalize_tag_names(config["tag_names"])
        args[:tags] = tag_names if tag_names.present?

        args
      end

      def normalize_tag_names(tag_names)
        Array
          .wrap(tag_names)
          .flat_map { |name| name.to_s.split(",") }
          .filter_map { |name| name.strip.presence }
      end
    end
  end
end

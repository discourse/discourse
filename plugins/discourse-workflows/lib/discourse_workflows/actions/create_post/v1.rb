# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module CreatePost
      class V1 < Actions::Base
        def self.identifier
          "action:create_post"
        end

        def self.icon
          "reply"
        end

        def self.color_key
          "teal"
        end

        def self.configuration_schema
          {
            topic_id: {
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
            reply_to_post_number: {
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
          { post: Schemas::Post.fields }
        end

        def execute_single(_context, item:, config:)
          topic = Topic.find(config["topic_id"])
          ensure_topic_is_open!(topic)

          author = resolve_author(config["user_id"])
          post = PostCreator.new(author, build_post_args(topic, config)).create!

          { post: Schemas::Post.resolve(post) }
        end

        private

        def ensure_topic_is_open!(topic)
          return if !topic.closed? && !topic.archived?

          raise ActiveRecord::RecordNotSaved.new(
                  I18n.t("discourse_workflows.errors.create_post.topic_closed_or_archived"),
                )
        end

        def build_post_args(topic, config)
          args = { topic_id: topic.id, raw: config["raw"], skip_workflows: true }

          if config["reply_to_post_number"].present?
            args[:reply_to_post_number] = config["reply_to_post_number"]
          end

          args
        end
      end
    end
  end
end

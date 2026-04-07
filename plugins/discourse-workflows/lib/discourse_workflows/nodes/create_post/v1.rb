# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module CreatePost
      class V1 < NodeType
        def self.identifier
          "action:create_post"
        end

        def self.icon
          "reply"
        end

        def self.color_key
          "teal"
        end

        def self.group
          "discourse_actions"
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

        def execute(exec_ctx)
          run_as_user = exec_ctx.run_as_user
          items =
            exec_ctx.input_items.map do |item|
              exec_ctx.with_item(item) do
                config = exec_ctx.resolve_config(@configuration)
                result = process(run_as_user, config)
                Item.new(result).to_h
              end
            end
          ItemContract.validate_items!(items, source: self.class.identifier)
          [items]
        end

        private

        def process(run_as_user, config)
          topic = Topic.find(config["topic_id"])
          ensure_topic_is_open!(topic)

          author = config["user_id"].present? ? User.find(config["user_id"]) : run_as_user
          post = PostCreator.new(author, build_post_args(topic, config)).create!

          { post: Schemas::Post.resolve(post) }
        end

        def ensure_topic_is_open!(topic)
          return unless topic.closed? || topic.archived?
          raise ActiveRecord::RecordNotSaved,
                I18n.t("discourse_workflows.errors.create_post.topic_closed_or_archived")
        end

        def build_post_args(topic, config)
          {
            topic_id: topic.id,
            raw: config["raw"],
            skip_workflows: true,
            reply_to_post_number: config["reply_to_post_number"].presence,
          }.compact
        end
      end
    end
  end
end

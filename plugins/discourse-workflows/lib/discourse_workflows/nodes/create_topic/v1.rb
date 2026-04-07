# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module CreateTopic
      class V1 < NodeType
        def self.identifier
          "action:create_topic"
        end

        def self.icon
          "plus"
        end

        def self.color_key
          "light-green"
        end

        def self.group
          "discourse_actions"
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
              ui: {
                control: :tags,
              },
            },
            user_id: {
              type: :integer,
              required: false,
            },
          }
        end

        def self.output_schema
          { topic: Schemas::Topic.fields, post_id: :integer, post_number: :integer }
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
          author = config["user_id"].present? ? User.find(config["user_id"]) : run_as_user
          tag_names = normalize_tag_names(config["tag_names"])

          DiscourseTools::CreateTopic.call(
            params: {
              title: config["title"],
              raw: config["raw"],
              category_id: (config["category_id"].presence&.to_i),
            },
            options: {
              tags: tag_names.presence,
              skip_workflows: true,
            },
            guardian: Guardian.new(author),
          ) do
            on_success do |post:|
              topic = post.topic
              {
                topic: Schemas::Topic.resolve(topic),
                post_id: post.id,
                post_number: post.post_number,
              }
            end
            on_failed_step(:create_post) { |step| raise step.error }
            on_failure { raise "Failed to create topic" }
          end
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
end

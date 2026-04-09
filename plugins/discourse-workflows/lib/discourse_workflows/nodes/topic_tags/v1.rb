# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTags
      class V1 < NodeType
        OPERATIONS = %w[add remove].freeze

        def self.identifier
          "action:topic_tags"
        end

        def self.icon
          "tags"
        end

        def self.color_key
          "orange"
        end

        def self.group
          "discourse_actions"
        end

        def self.configuration_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            topic_id: {
              type: :string,
              required: true,
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
          }
        end

        def execute(exec_ctx)
          run_as_user = exec_ctx.run_as_user
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(run_as_user, config)
              Item.new(result).to_h
            end
          ItemContract.validate_items!(items, source: self.class.identifier)
          [items]
        end

        private

        def process(run_as_user, config)
          topic = Topic.find(config["topic_id"])
          guardian = Guardian.new(run_as_user)

          names =
            Array
              .wrap(config["tag_names"])
              .flat_map { |n| n.to_s.split(",") }
              .filter_map { |n| n.strip.presence }
          raise "No tag names provided" if names.empty?

          case config["operation"]
          when "remove"
            old_tag_names = topic.tags.pluck(:name)
            desired_tag_names = old_tag_names - names
            tag_topic!(topic, guardian, desired_tag_names)
            removed = old_tag_names - topic.reload.tags.pluck(:name)
            { tag_names: removed, topic_id: topic.id }
          else
            tag_topic!(topic, guardian, names, append: true)
            { tag_names: topic.reload.tags.pluck(:name) & names, topic_id: topic.id }
          end
        end

        def tag_topic!(topic, guardian, tag_names, append: false)
          unless DiscourseTagging.tag_topic_by_names(topic, guardian, tag_names, append:)
            raise "Tag operation failed: #{topic.errors.full_messages.join(", ")}"
          end
          topic.save!
        end
      end
    end
  end
end

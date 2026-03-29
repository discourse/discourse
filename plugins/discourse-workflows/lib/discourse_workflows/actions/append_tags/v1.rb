# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module AppendTags
      class V1 < Actions::Base
        def self.identifier
          "action:append_tags"
        end

        def self.icon
          "tags"
        end

        def self.color_key
          "orange"
        end

        def self.configuration_schema
          {
            topic_id: {
              type: :string,
              required: true,
            },
            tag_names: {
              type: :string,
              required: true,
              ui: {
                control: :tags,
              },
            },
          }
        end

        def execute_single(context, item:, config:)
          topic = Topic.find(config["topic_id"])

          names =
            Array
              .wrap(config["tag_names"])
              .flat_map { |n| n.to_s.split(",") }
              .filter_map { |n| n.strip.presence }
          raise "No tag names provided" if names.empty?

          tags = names.map { |name| Tag.find_or_create_by!(name: name) }

          new_tags = tags - topic.tags.to_a
          topic.tags << new_tags if new_tags.any?

          { tag_names: tags.map(&:name), topic_id: topic.id }
        end
      end
    end
  end
end

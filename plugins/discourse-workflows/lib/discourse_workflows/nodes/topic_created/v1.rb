# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCreated
      class V1 < NodeType
        TOPIC_TYPE_OPTIONS = %w[all topics personal_messages].freeze

        description(
          name: "trigger:topic_created",
          version: "1.0",
          defaults: {
            icon: "plus",
            color: "teal",
          },
          group: "discourse_triggers",
          events: [:topic_created],
          output_contracts: [
            { schema: Schema.merge(Schema::TOPIC_LIST_ITEM_SCHEMA, Schema::POST_SCHEMA) },
          ],
          properties: {
            topic_type: {
              type: :options,
              required: true,
              default: "topics",
              options: TOPIC_TYPE_OPTIONS,
            },
            group_inbox_id: {
              type: :integer,
              required: false,
              type_options: {
                load_options_method: "groups",
              },
              display_options: {
                show: {
                  topic_type: %w[personal_messages],
                },
              },
              ui: {
                control: :group_select,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.topic_created.group_inbox_id_placeholder",
              },
            },
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
            include_subcategories: {
              type: :boolean,
              required: false,
              default: true,
              ui: {
                control: :checkbox,
              },
              display_options: {
                show: {
                  category_id: [{ condition: { exists: true } }],
                },
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "groups"
            ::Group
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def initialize(topic, opts = nil, *)
          super(parameters: {})
          @topic = topic
          @opts = opts
        end

        def valid?
          @topic.present? && !@opts&.dig(:skip_workflows)
        end

        def output
          { post: post_data(@topic.first_post), topic: topic_data(@topic) }
        end

        def matches?(trigger_ctx)
          matches_topic_type?(trigger_ctx.get_node_parameter("topic_type", "topics")) &&
            matches_group_inbox?(trigger_ctx.get_node_parameter("group_inbox_id")) &&
            matches_category?(
              trigger_ctx.get_node_parameter("category_id"),
              trigger_ctx.get_node_parameter("include_subcategories", true),
            ) && matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def post_data(post)
          serialize_post(post)
        end

        def matches_topic_type?(topic_type)
          case topic_type.presence || "topics"
          when "all"
            true
          when "topics"
            !@topic.private_message?
          when "personal_messages"
            @topic.private_message?
          else
            false
          end
        end

        def matches_group_inbox?(group_id)
          return true if group_id.blank?
          return false if !@topic.private_message?

          @topic.allowed_groups.exists?(id: group_id.to_i)
        end

        def matches_category?(category_id, include_subcategories)
          return true if category_id.blank?

          category_id = category_id.to_i
          return @topic.category_id == category_id if include_subcategories == false

          ::Category.subcategory_ids(category_id).include?(@topic.category_id)
        end

        def matches_tags?(tag_names)
          tag_names.empty? || (topic_tag_names & tag_names).any?
        end

        def topic_tag_names
          @topic_tag_names ||= @topic.tags.pluck(:name)
        end
      end
    end
  end
end

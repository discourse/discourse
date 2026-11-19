# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostCreated
      class V1 < NodeType
        POST_TYPE_OPTIONS = %w[regular whisper].freeze
        DEFAULT_POST_TYPE = "regular"

        description(
          name: "trigger:post_created",
          version: "1.0",
          defaults: {
            icon: "comment",
            color: "indigo",
          },
          group: "discourse_triggers",
          event: :post_created,
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::POST_SCHEMA,
                  Schema::TOPIC_LIST_ITEM_SCHEMA,
                  Schema::USER_SCHEMA,
                ),
            },
          ],
          properties: {
            **TOPIC_TYPE_FILTER_PROPERTIES,
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
                none: "discourse_workflows.post_created.group_inbox_id_placeholder",
              },
            },
            post_type: {
              type: :options,
              required: true,
              default: DEFAULT_POST_TYPE,
              options: POST_TYPE_OPTIONS,
            },
            **TOPIC_SCOPE_FILTER_PROPERTIES,
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

        def initialize(post, opts = nil, *)
          super(parameters: {})
          @post = post
          @opts = opts
        end

        def valid?
          return false if @post.blank?
          return false if @post.topic.blank?
          return false if @opts&.dig(:skip_workflows)

          POST_TYPE_OPTIONS.include?(post_type_name)
        end

        def output
          {
            post: serialize_post(@post),
            topic: serialize_topic_list_item(@post.topic),
            user: serialize_user(@post.user),
          }
        end

        def matches?(trigger_ctx)
          topic = @post.topic
          post_type = trigger_ctx.get_node_parameter("post_type").presence || DEFAULT_POST_TYPE

          return false if post_type != post_type_name
          return false if !matches_topic_type?(topic, trigger_ctx.get_node_parameter("topic_type"))
          return false if !matches_topic_filters?(topic, trigger_ctx)

          matches_group_inbox?(topic, trigger_ctx.get_node_parameter("group_inbox_id"))
        end

        private

        def post_type_name
          ::Post.types.key(@post.post_type).to_s
        end
      end
    end
  end
end

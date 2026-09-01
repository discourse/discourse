# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostCreated
      class V1 < NodeType
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
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
          },
        )

        class << self
          def load_options_context(context)
            case context.method_name
            when "groups"
              ::Group
                .order(:name)
                .pluck(:id, :name)
                .select { |_, name| context.matches_filter?(name) }
                .map { |id, name| { id:, name: } }
            end
          end
        end

        def initialize(post, opts = nil, *)
          super(parameters: {})
          @post = post
          @opts = opts
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == ::Post.types[:regular] &&
            !@opts&.dig(:skip_workflows)
        end

        def output
          { post: post_data(@post), topic: topic_data(@post.topic), user: user_data(@post.user) }
        end

        def matches?(trigger_ctx)
          topic = @post.topic

          matches_topic_type?(topic, trigger_ctx.get_node_parameter("topic_type", "topics")) &&
            matches_group_inbox?(topic, trigger_ctx.get_node_parameter("group_inbox_id")) &&
            matches_category_ids?(
              topic.category_id,
              category_ids_parameter(trigger_ctx),
              include_subcategories: trigger_ctx.get_node_parameter("include_subcategories", true),
            ) &&
            matches_tags?(topic, normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def post_data(post)
          serialize_post(post)
        end

        def user_data(user)
          serialize_user(user)
        end
      end
    end
  end
end

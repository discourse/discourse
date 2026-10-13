# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostReactionChanged
        class V1 < DiscourseWorkflows::NodeType
          CHANGES = %w[added replaced removed].freeze

          OUTPUT_SCHEMA =
            Schema.merge(
              Schema::POST_SCHEMA,
              Schema::TOPIC_LIST_ITEM_SCHEMA,
              Schema::USER_SCHEMA,
              Schema.document(
                "change" => {
                  "type" => "string",
                  "enum" => CHANGES,
                },
                "reaction" => {
                  "type" => %w[string null],
                },
                "previous_reaction" => {
                  "type" => %w[string null],
                },
              ),
            ).freeze

          description(
            name: "trigger:post_reaction_changed",
            version: "1.0",
            defaults: {
              icon: "far-face-smile",
              color: "yellow",
            },
            group: "discourse_triggers",
            event: :post_reaction_toggled,
            available: -> { SiteSetting.discourse_reactions_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_reactions",
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              changes: {
                type: :multi_options,
                required: false,
                default: [],
                options: CHANGES,
              },
              reaction: {
                type: :emoji,
                required: false,
                no_data_expression: true,
              },
              **TOPIC_SCOPE_FILTER_PROPERTIES,
            },
          )

          def initialize(post, user, previous_reaction)
            super(parameters: {})
            @post = post
            @user = user
            @previous_reaction = previous_reaction
          end

          def valid?
            @post.topic.present? && reaction != @previous_reaction
          end

          def user_id
            @user.id
          end

          def output
            {
              change:,
              reaction:,
              previous_reaction: @previous_reaction,
              post: serialize_post(@post),
              topic: topic_data(@post.topic),
              user: serialize_user(@user),
            }
          end

          def matches?(trigger_ctx)
            filter = trigger_ctx.get_node_parameter("reaction").to_s.delete(":").presence

            return false if !matches_changes?(trigger_ctx, change)
            return false if filter && [reaction, @previous_reaction].exclude?(filter)

            matches_topic_filters?(@post.topic, trigger_ctx)
          end

          private

          # Looked up lazily so toggles nobody listens to don't pay for the query.
          def reaction
            return @reaction if defined?(@reaction)

            @reaction =
              ::DiscourseReactions::ReactionManager.reaction_value_for(user: @user, post: @post)
          end

          def change
            if @previous_reaction.nil?
              "added"
            elsif reaction.nil?
              "removed"
            else
              "replaced"
            end
          end
        end
      end
    end
  end
end

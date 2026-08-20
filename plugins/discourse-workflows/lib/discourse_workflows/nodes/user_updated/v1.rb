# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserUpdated
      class V1 < NodeType
        description(
          name: "trigger:user_updated",
          version: "1.0",
          defaults: {
            icon: "user-pen",
            color: "teal",
          },
          group: "discourse_triggers",
          events: [:user_updated],
          output_contracts: [{ schema: Schema::USER_EVENT_SCHEMA }],
          properties: {
            group_ids: {
              type: :multi_options,
              required: false,
              default: [],
              type_options: {
                load_options_method: "groups",
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
          },
          capabilities: {
            provides_current_user: true,
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

        def initialize(user, *)
          super(parameters: {})
          @user = user
        end

        def valid?
          @user.present? && @user.human?
        end

        def user_id
          @user.id
        end

        def output
          {
            user:
              serialize_user(@user).merge(
                staged: @user.staged?,
                created_at: @user.created_at&.iso8601,
              ),
          }
        end

        def matches?(trigger_ctx)
          matches_user_groups?(@user, trigger_ctx.get_node_parameter("group_ids", []))
        end
      end
    end
  end
end

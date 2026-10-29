# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserAddedToGroup
      class V1 < NodeType
        description(
          name: "trigger:user_added_to_group",
          version: "1.0",
          defaults: {
            icon: "user-plus",
            color: "teal",
          },
          group: "discourse_triggers",
          event: :user_added_to_group,
          output_contracts: [
            { schema: Schema.merge(Schema::USER_ADDED_TO_GROUP_SCHEMA, Schema::ACTOR_SCHEMA) },
          ],
          properties: {
            group_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "groups",
              },
              no_data_expression: true,
              ui: {
                control: :group_select,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
          },
        )

        def self.load_options_context(context)
          load_group_options(context)
        end

        def initialize(user, group, payload = {})
          super(parameters: {})
          @user = user
          @group = group
          @automatic = payload[:automatic]
          @actor = payload[:acting_user]
        end

        def valid?
          @user.present? && @group.present?
        end

        def output
          {
            user: serialize_user(@user),
            group: serialize_basic_group(@group),
            membership: {
              action: "added",
              automatic: @automatic == true,
            },
            actor: serialize_user(@actor),
          }
        end

        def matches?(trigger_ctx)
          group_id = trigger_ctx.get_node_parameter("group_id")
          group_id.present? && @group.id == group_id.to_i
        end
      end
    end
  end
end

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
          events: [:user_added_to_group],
          output_contracts: [{ schema: Schema::USER_ADDED_TO_GROUP_SCHEMA }],
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
                none: "discourse_workflows.user_added_to_group.group_id_placeholder",
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

        def initialize(user, group, options = {})
          super(parameters: {})
          @user = user
          @group = group
          @automatic =
            options.respond_to?(:to_h) ? options.to_h.with_indifferent_access[:automatic] : nil
        end

        def valid?
          @user.present? && @group.present?
        end

        def output
          {
            user: serialize_user(@user),
            group: group_data,
            membership: {
              action: "added",
              automatic: @automatic == true,
            },
          }
        end

        def matches?(trigger_ctx)
          group_id = trigger_ctx.get_node_parameter("group_id")
          group_id.present? && @group.id == group_id.to_i
        end

        private

        def group_data
          {
            id: @group.id,
            name: @group.name,
            full_name: @group.full_name,
            automatic: @group.automatic?,
          }
        end
      end
    end
  end
end

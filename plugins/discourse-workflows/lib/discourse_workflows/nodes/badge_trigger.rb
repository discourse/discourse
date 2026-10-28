# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Badge granted and Badge revoked: a user, a badge, who acted, and an optional badge filter. Including
    # nodes set @user, @badge and @actor.
    module BadgeTrigger
      def self.description(name:, event:, icon:, color:, output_schema:)
        {
          name:,
          version: "1.0",
          defaults: {
            icon:,
            color:,
          },
          group: "discourse_triggers",
          event:,
          output_contracts: [{ schema: output_schema }],
          properties: {
            badge_id: {
              type: :integer,
              required: false,
              type_options: {
                load_options_method: "badges",
              },
              no_data_expression: true,
              ui: {
                control: :combo_box,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.#{name.delete_prefix("trigger:")}.badge_id_placeholder",
              },
            },
          },
        }
      end

      def valid?
        @badge.present? && @user.present?
      end

      def output
        {
          user: serialize_user(@user),
          badge: serialize_badge(@badge),
          actor: serialize_user(@actor),
        }
      end

      def matches?(trigger_ctx)
        badge_id = trigger_ctx.get_node_parameter("badge_id")
        badge_id.blank? || @badge.id == badge_id.to_i
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module BadgeGranted
      class V1 < NodeType
        description(
          name: "trigger:badge_granted",
          version: "1.0",
          defaults: {
            icon: "certificate",
            color: "yellow",
          },
          group: "discourse_triggers",
          events: [:user_badge_granted],
          output_contracts: [{ schema: Schema::BADGE_GRANTED_SCHEMA }],
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
                none: "discourse_workflows.badge_granted.badge_id_placeholder",
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "badges"
            ::Badge
              .where(enabled: true)
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def initialize(badge_id, user_id)
          super(parameters: {})
          @badge = ::Badge.find_by(id: badge_id)
          @user = ::User.find_by(id: user_id)
        end

        def valid?
          @badge.present? && @user.present?
        end

        def output
          { user: serialize_user(@user), badge: badge_data }
        end

        def matches?(trigger_ctx)
          badge_id = trigger_ctx.get_node_parameter("badge_id")
          badge_id.blank? || @badge.id == badge_id.to_i
        end

        private

        def badge_data
          {
            id: @badge.id,
            name: @badge.name,
            description: @badge.description.presence,
            badge_type_id: @badge.badge_type_id,
            icon: @badge.icon,
            image_url: @badge.image_url,
            grant_count: @badge.grant_count,
            system: @badge.system?,
            multiple_grant: @badge.multiple_grant?,
          }
        end
      end
    end
  end
end

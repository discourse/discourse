# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module AwardBadge
      class V1 < Actions::Base
        def self.identifier
          "action:award_badge"
        end

        def self.configuration_schema
          {
            user_id: {
              type: :string,
              required: true,
            },
            badge_id: {
              type: :integer,
              required: true,
              ui: {
                control: :combo_box,
                options_source: "badges",
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.award_badge.badge_id_placeholder",
              },
            },
          }
        end

        def self.metadata
          { badges: Badge.order(:name).pluck(:id, :name).map { |id, name| { id:, name: } } }
        end

        def self.output_schema
          { user_id: :integer, username: :string, badge_id: :integer, badge_name: :string }
        end

        def execute_single(_context, item:, config:)
          user = User.find(config["user_id"])
          badge = Badge.find(config["badge_id"])

          BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

          { user_id: user.id, username: user.username, badge_id: badge.id, badge_name: badge.name }
        end
      end
    end
  end
end

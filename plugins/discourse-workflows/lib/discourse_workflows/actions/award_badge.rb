# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    class AwardBadge < Base
      def self.identifier
        "action:award_badge"
      end

      def self.configuration_schema
        { user_id: { type: :string, required: true }, badge_id: { type: :string, required: true } }
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

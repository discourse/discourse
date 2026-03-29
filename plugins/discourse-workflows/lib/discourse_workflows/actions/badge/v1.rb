# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Badge
      class V1 < Actions::Base
        OPERATIONS = %w[grant revoke].freeze

        def self.identifier
          "action:badge"
        end

        def self.icon
          "certificate"
        end

        def self.color_key
          "yellow"
        end

        def self.configuration_schema
          {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "grant",
              ui: {
                expression: true,
              },
            },
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
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
                none: "discourse_workflows.badge.badge_id_placeholder",
              },
            },
          }
        end

        def self.metadata
          { badges: ::Badge.order(:name).pluck(:id, :name).map { |id, name| { id:, name: } } }
        end

        def self.output_schema
          { user_id: :integer, username: :string, badge_id: :integer, badge_name: :string }
        end

        def execute_single(_context, item:, config:)
          user = User.find_by_username(config["username"])
          raise ActiveRecord::RecordNotFound.new("Couldn't find User") if user.nil?
          badge = ::Badge.find(config["badge_id"])

          case config["operation"]
          when "revoke"
            user_badge = UserBadge.find_by(user: user, badge: badge)
            BadgeGranter.revoke(user_badge, revoked_by: run_as_user) if user_badge
          else
            BadgeGranter.grant(badge, user, granted_by: run_as_user)
          end

          { user_id: user.id, username: user.username, badge_id: badge.id, badge_name: badge.name }
        end
      end
    end
  end
end

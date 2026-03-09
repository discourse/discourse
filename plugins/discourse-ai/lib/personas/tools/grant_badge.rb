# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class GrantBadge < Tool
        def self.signature
          {
            name: name,
            description: "Grants a badge to a user.",
            parameters: [
              {
                name: "username",
                description: "The username of the user to grant the badge to",
                type: "string",
                required: true,
              },
              {
                name: "badge_name",
                description: "The name of the badge to grant",
                type: "string",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the badge is being granted",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "grant_badge"
        end

        def invoke
          if !guardian.can_grant_badges?(nil)
            return error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.not_allowed"))
          end

          user = User.find_by(username: parameters[:username])
          if !user
            return error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.user_not_found"))
          end

          badge = Badge.find_by(name: parameters[:badge_name])
          if !badge
            return(error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.badge_not_found")))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.no_reason"))
          end

          if !badge.enabled?
            return(error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.badge_disabled")))
          end

          user_badge = BadgeGranter.grant(badge, user, granted_by: acting_user)

          if user_badge
            { status: "success", message: I18n.t("discourse_ai.ai_bot.grant_badge.success") }
          else
            error_response(I18n.t("discourse_ai.ai_bot.grant_badge.errors.grant_failed"))
          end
        end

        def description_args
          { username: parameters[:username], badge_name: parameters[:badge_name] }
        end
      end
    end
  end
end

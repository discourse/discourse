# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ListUpcomingChanges < Tool
        def self.name
          "list_upcoming_changes"
        end

        def self.signature
          {
            name: name,
            description:
              "List this site's available Upcoming Changes, including hidden feature settings, rollout status, enabled audiences, and dependencies. Read-only; use the returned admin URL to manage them, not change_site_setting.",
            parameters: [],
          }
        end

        def invoke
          unless context&.user&.admin? && guardian.is_admin?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.list_upcoming_changes.errors.not_allowed"))
            )
          end

          # Use the admin page's visibility rules without marking it as visited
          # for the requesting administrator.
          result = UpcomingChanges::List.call(guardian: Discourse.system_user.guardian)
          unless result.success?
            return error_response(I18n.t("discourse_ai.ai_bot.list_upcoming_changes.errors.failed"))
          end

          {
            url: "#{Discourse.base_url}/admin/config/upcoming-changes",
            changes:
              result[:upcoming_changes].map do |change|
                change.slice(
                  :setting,
                  :humanized_name,
                  :description,
                  :value,
                  :plugin,
                  :groups,
                  :depends_on,
                  :depends_on_met,
                  :dependents,
                  :overriding_defaults,
                ).merge(
                  upcoming_change:
                    change[:upcoming_change].slice(
                      :status,
                      :enabled_for,
                      :impact_role,
                      :allow_enabled_for,
                      :learn_more_url,
                      :permanent_warning,
                    ),
                )
              end,
          }
        end
      end
    end
  end
end

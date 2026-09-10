# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SearchDiscourseNavigation < Tool
        MAX_RESULTS = 8
        MAX_QUERY_LENGTH = 200

        CORE_PATHS = {
          settings: "/admin/site_settings/category/all_settings",
          users: "/admin/users/list/active",
          groups: "/admin/groups",
          review: "/review",
          invites: "/new-invite",
          categories: "/categories",
          tags: "/tags",
          themes: "/admin/config/customize/themes",
          authentication: "/admin/config/login-and-authentication",
          backups: "/admin/backups",
        }.freeze

        def self.signature
          {
            name: name,
            description:
              "Find verified navigation URLs on this site, including available plugin pages. Use concise keywords for the destination or task, such as 'billing subscription' or 'themes'. Reuse returned URLs exactly. No results means no verified destination was found; never invent a URL.",
            parameters: [
              {
                name: "query",
                description: "Keywords describing the page or task",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "search_discourse_navigation"
        end

        def invoke
          if !guardian.is_admin?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.search_discourse_navigation.not_allowed"))
            )
          end

          query = parameters[:query].to_s.strip
          if query.blank? || query.length > MAX_QUERY_LENGTH
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.search_discourse_navigation.invalid_query",
                  max: MAX_QUERY_LENGTH,
                ),
              )
            )
          end

          terms = query.downcase.split(/\s+/).uniq
          matches =
            destinations.filter_map do |destination|
              next if !destination.available?(guardian)

              search_text = destination.search_text
              score = terms.count { |term| search_text.include?(term) }
              next if score.zero?

              [score, destination]
            end

          results =
            matches
              .sort_by { |score, destination| [-score, destination.id] }
              .first(MAX_RESULTS)
              .map { |_, destination| destination.to_h }
          @result_count = results.length

          { destinations: results }
        end

        private

        def destinations
          core =
            CORE_PATHS.map do |id, path|
              NavigationDestination.new(
                id: "core:#{id}",
                path: path,
                title: "discourse_ai.ai_bot.navigation.#{id}.title",
                description: "discourse_ai.ai_bot.navigation.#{id}.description",
              ) do |requesting_guardian|
                requesting_guardian.is_admin? && (id != :tags || SiteSetting.tagging_enabled) &&
                  (id != :invites || requesting_guardian.can_invite_to_forum?)
              end
            end

          core + DiscoursePluginRegistry.navigation_destinations
        end

        def description_args
          { count: @result_count || 0 }
        end
      end
    end
  end
end

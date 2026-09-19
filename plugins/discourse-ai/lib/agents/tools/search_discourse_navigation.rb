# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SearchDiscourseNavigation < Tool
        MAX_RESULTS = 8
        MAX_QUERY_LENGTH = 200

        CORE_PATHS = {
          settings: "/admin/site_settings/category/all_results",
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
              "Find verified navigation URLs on this site, including available plugin pages. Use concise keywords for the destination or task, such as 'billing subscription' or 'themes'. Reuse returned URLs exactly. Optionally provide a URL to verify against available navigation destinations and category URLs. If verification returns a canonical_url, use it unchanged. If neither a destination nor a canonical_url is returned, no verified destination was found; never invent a URL.",
            parameters: [
              {
                name: "query",
                description: "Keywords describing the page or task",
                type: "string",
                required: true,
              },
              {
                name: "url",
                description:
                  "An absolute site URL to verify before linking to it. Verification requires an exact match, including the absence of extra IDs, path segments, query parameters, or fragments.",
                type: "string",
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
          available_destinations =
            destinations.select { |destination| destination.available?(guardian) }
          matches =
            available_destinations.filter_map do |destination|
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

          result = { destinations: results }
          if parameters[:url].present?
            result[:url_verification] = verify_url(parameters[:url].to_s, available_destinations)
          end
          result
        end

        private

        def verify_url(url, available_destinations)
          canonical_urls = available_destinations.map { |destination| destination.to_h[:url] }

          category_prefix = "#{Discourse.base_url}/c/"
          if url.start_with?(category_prefix)
            category_ids = url.delete_prefix(category_prefix).split(%r{[/?#]}).grep(/\A\d+\z/)
            canonical_urls.concat(
              Category
                .secured(guardian)
                .where(id: category_ids)
                .map { |category| "#{Discourse.base_url_no_prefix}#{category.url}" },
            )
          end

          canonical_url = canonical_urls.find { |candidate| candidate == url }
          canonical_url ||=
            canonical_urls
              .sort_by { |candidate| -candidate.length }
              .find do |candidate|
                %w[/ ? #].any? { |separator| url.start_with?("#{candidate}#{separator}") }
              end

          { verified: canonical_url == url, canonical_url: canonical_url }
        end

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

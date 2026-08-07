# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ListUsers < Tool
        def self.signature
          {
            name: name,
            description:
              "Lists users on the current Discourse instance, optionally filtered by search term, groups, account status, and topic creation permission in a category.",
            parameters: [
              {
                name: "query",
                description: "Optional username or name search term.",
                type: "string",
                required: false,
              },
              {
                name: "groups",
                description:
                  "Optional group names or IDs. When present, only users in at least one of these groups are returned.",
                type: "array",
                item_type: "string",
                required: false,
              },
              {
                name: "category_name",
                description:
                  "Optional category name or slug. When present, only users who can create topics in that category are returned.",
                type: "string",
                required: false,
              },
              {
                name: "real",
                description:
                  "Optional boolean. When true, only regular human users are returned; when false, only non-regular human user records such as anonymous shadow users are returned.",
                type: "boolean",
                required: false,
              },
              {
                name: "active",
                description: "Optional boolean filter for active or inactive users.",
                type: "boolean",
                required: false,
              },
              {
                name: "staged",
                description: "Optional boolean filter for staged or non-staged users.",
                type: "boolean",
                required: false,
              },
              {
                name: "suspended",
                description: "Optional boolean filter for suspended or non-suspended users.",
                type: "boolean",
                required: false,
              },
              {
                name: "limit",
                description: "Maximum number of users to return, capped at 100.",
                type: "integer",
                required: false,
              },
            ],
          }
        end

        def self.name
          "users"
        end

        def invoke
          result = DiscourseAi::Agents::UserFinder.new(parameters, guardian: guardian).call
          return error_response(result[:error]) if result[:error]

          @last_count = result[:users].length
          format_results(result[:users])
        end

        private

        def description_args
          { count: @last_count || 0 }
        end
      end
    end
  end
end

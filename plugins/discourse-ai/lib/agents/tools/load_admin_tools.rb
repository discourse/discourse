# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class LoadAdminTools < Tool
        def self.name
          "load_admin_tools"
        end

        def self.signature
          {
            name:,
            description:
              "Load administration tools for the next tool call. Choose settings (site settings), categories_tags (categories and tags), moderation (review queue, topics, posts and users), or appearance (colors, fonts, themes and theme-app access). Load multiple groups for mixed requests. This does not change the site or grant permissions.",
            parameters: [
              {
                name: "groups",
                type: "array",
                item_type: "string",
                required: true,
                description: "One or more of: settings, categories_tags, moderation, appearance",
              },
            ],
          }
        end

        def self.available_for_context?(context)
          context&.user&.admin? == true
        end

        def invoke
          if !context.user&.admin?
            return error_response("Only administrators can load administration tools.")
          end
          if !agent.is_a?(DiscourseAdminAssistant)
            return error_response("This tool requires the Admin Assistant.")
          end

          agent.load_tool_groups(parameters[:groups], context: context, llm: llm)
        end
      end
    end
  end
end

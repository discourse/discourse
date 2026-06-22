# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowAiAgentCatalog < Base
        MAX_RESULTS = 10
        PROMPT_EXCERPT_LENGTH = 500

        def self.signature
          {
            name: name,
            description:
              "Searches existing Discourse AI agents so workflow drafts can reuse a suitable enabled agent instead of creating a duplicate.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                query: {
                  type: "string",
                  description: "Search terms for the needed agent behavior, name, or description.",
                },
                include_disabled: {
                  type: "boolean",
                  description:
                    "Whether to include disabled agents for awareness. Defaults to false; disabled agents should not be used in workflow nodes.",
                },
              },
            },
          }
        end

        def self.name
          "workflow_ai_agent_catalog"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!
          return error_response("AI agents are not available") if !defined?(::AiAgent)

          agents = matching_agents
          {
            status: "success",
            agents: agents.map { |agent| serialize_agent(agent) },
            instruction:
              "Reuse a suitable enabled agent by setting action:ai_agent agent_id to its id. If no suitable enabled agent exists, propose a create_ai_agent operation with name, description, and system_prompt.",
          }
        end

        private

        def matching_agents
          scope = ::AiAgent.order("lower(name) ASC")
          scope = scope.where(enabled: true) if !include_disabled?

          terms = query_terms
          records = scope.limit(::AiAgent::MAX_AGENTS_PER_SITE).to_a
          records = records.select { |agent| matches_terms?(agent, terms) } if terms.present?
          records.first(MAX_RESULTS)
        end

        def include_disabled?
          parameters[:include_disabled].to_s == "true" || parameters[:include_disabled] == true
        end

        def query_terms
          parameters[:query].to_s.downcase.scan(/[a-z0-9_:-]+/).uniq
        end

        def matches_terms?(agent, terms)
          words = [agent.name, agent.description, agent.system_prompt].join(" ")
            .downcase
            .scan(/[a-z0-9_:-]+/)
          terms.all? { |term| words.any? { |word| word == term || word.start_with?(term) } }
        end

        def serialize_agent(agent)
          {
            id: agent.id,
            name: agent.name,
            description: agent.description,
            enabled: agent.enabled?,
            system_prompt_excerpt: agent.system_prompt.to_s.truncate(PROMPT_EXCERPT_LENGTH),
          }
        end
      end
    end
  end
end

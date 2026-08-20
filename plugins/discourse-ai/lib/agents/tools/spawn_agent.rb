# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SpawnAgent < Tool
        DESCRIPTION_PREVIEW_LENGTH = 300

        class << self
          attr_accessor :parent_agent_id_value, :allowed_agents_value

          def class_instance(parent_agent_id, agents)
            catalog =
              agents.each_with_object({}) do |agent, result|
                result[agent.id] = agent_catalog_entry(agent)
              end
            class_instance_from_catalog(parent_agent_id, catalog)
          end

          def agent_catalog_entry(agent)
            if agent.is_a?(AiAgent) &&
                 (system_agent = DiscourseAi::Agents::Agent.system_agents_by_id[agent.id])
              { name: system_agent.name, description: system_agent.description }
            else
              { name: agent.name, description: agent.description }
            end
          end

          def class_instance_from_catalog(parent_agent_id, catalog)
            klass = Class.new(self)
            klass.parent_agent_id_value = parent_agent_id
            klass.allowed_agents_value = catalog.deep_dup
            klass
          end

          def name
            "spawn_agent"
          end

          def parent_agent_id
            parent_agent_id_value
          end

          def allowed_agents
            allowed_agents_value || {}
          end

          def signature
            descriptions =
              allowed_agents.map do |id, agent|
                preview = agent[:description].to_s.truncate(DESCRIPTION_PREVIEW_LENGTH)
                "#{id}: #{agent[:name]} — #{preview}"
              end

            {
              name: name,
              description: [
                I18n.t("discourse_ai.ai_bot.spawn_agent.description"),
                descriptions.join("\n"),
              ].compact_blank.join("\n\n"),
              json_schema: {
                type: "object",
                properties: {
                  agent_id: {
                    type: "integer",
                    enum: allowed_agents.keys,
                  },
                  prompt: {
                    type: "string",
                    maxLength: SubagentRunner::MAX_PROMPT_LENGTH,
                    description: I18n.t("discourse_ai.ai_bot.spawn_agent.prompt_description"),
                  },
                },
                required: %w[agent_id prompt],
                additionalProperties: false,
              },
            }
          end

          def token_count
            DiscourseAi::Tokenizer::OpenAiCl100kTokenizer.size(signature.to_json)
          end
        end

        def summary
          I18n.t("discourse_ai.ai_bot.spawn_agent.summary", agent: safe_agent_name)
        end

        def details
          if @result&.dig(:status) == "ok"
            prompt
          else
            I18n.t("discourse_ai.ai_bot.spawn_agent.failed")
          end
        end

        def invoke
          @result =
            SubagentRunner
              .new(
                parent_agent: agent,
                child_id: agent_id,
                prompt: prompt,
                context: context,
                parent_llm: llm,
              )
              .run { |delegated_prompt| yield(delegated_prompt) if block_given? }
        end

        private

        def agent_id
          value = parameters[:agent_id] || parameters["agent_id"]
          return value if value.is_a?(Integer)
          value.to_i if value.is_a?(String) && value.match?(/\A-?\d+\z/)
        end

        def prompt
          parameters[:prompt] || parameters["prompt"]
        end

        def safe_agent_name
          return I18n.t("discourse_ai.ai_bot.spawn_agent.unknown_agent") if !agent_id
          return I18n.t("discourse_ai.ai_bot.spawn_agent.unknown_agent") if !currently_allowed?

          self.class.allowed_agents.dig(agent_id, :name) ||
            I18n.t("discourse_ai.ai_bot.spawn_agent.unknown_agent")
        end

        def currently_allowed?
          return @currently_allowed if defined?(@currently_allowed)

          parent = AiAgent.find_by(id: self.class.parent_agent_id)
          @currently_allowed = parent&.subagent_ids&.include?(agent_id) || false
        end
      end
    end
  end
end

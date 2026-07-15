# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class AgentConfigurationValidator
      Result =
        Struct.new(
          :classification_type,
          :agent_id,
          :agent_name,
          :expected_keys,
          :actual_keys,
          :problems,
          keyword_init: true,
        ) do
          def valid?
            problems.empty?
          end
        end

      def self.validate(classification_type, agent_id)
        new(classification_type, agent_id).validate
      end

      def initialize(classification_type, agent_id)
        @classification_type = classification_type.to_s
        @agent_id = agent_id.to_i
      end

      def validate
        problems = []
        problems << :missing_agent if agent.blank?
        problems << :missing_llm if agent.present? && model.blank?
        if agent.present? && actual_keys.sort != expected_keys.sort
          problems << :invalid_response_format
        end

        Result.new(
          classification_type: @classification_type,
          agent_id: @agent_id,
          agent_name: agent&.name,
          expected_keys: expected_keys,
          actual_keys: actual_keys,
          problems: problems,
        )
      end

      private

      def agent
        @agent ||= AiAgent.find_by_id_from_cache(@agent_id)
      end

      def model
        @model ||=
          begin
            agent_klass = agent.class_instance
            model_id = agent_klass.default_llm_id || SiteSetting.ai_default_llm_model

            model_id.present? ? LlmModel.find_by(id: model_id) : LlmModel.last
          end
      end

      def expected_keys
        @expected_keys ||= PostClassification.labels_for(@classification_type)
      end

      def actual_keys
        @actual_keys ||=
          agent&.response_format.to_a.filter_map { |format| format["key"].presence } || []
      end
    end
  end
end

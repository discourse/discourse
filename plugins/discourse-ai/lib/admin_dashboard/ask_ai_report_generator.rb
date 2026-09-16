# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    class AskAiReportGenerator
      InvalidAnalysis = Class.new(StandardError)
      def initialize(report)
        @report = report
      end

      def generate
        asks = @report.selected_logs.pluck(:id, :query, :semantic_query)
        unless asks.size == @report.reported_ask_count
          raise InvalidAnalysis, "Selected asks are no longer available"
        end
        input =
          asks.map do |id, query, rewrite|
            { id:, query: query.first(600), rewrite: rewrite.to_s.first(300) }
          end
        agent = AiAgent.find(SiteSetting.ai_ask_ai_report_agent).class_instance.new
        prompt =
          DiscourseAi::Completions::Prompt.new(
            agent.system_prompt,
            messages: [
              {
                type: :user,
                content: {
                  start_date: @report.start_date,
                  end_date: @report.end_date,
                  question_count: input.size,
                  question_ids: input.map { |question| question[:id] },
                  questions: input,
                }.to_json,
              },
            ],
          )
        llm =
          DiscourseAi::Completions::Llm.proxy(
            LlmModel.find(agent.class.default_llm_id.presence || SiteSetting.ai_default_llm_model),
          )
        if llm.tokenizer.size(prompt.messages.to_json) + 8000 > llm.max_prompt_tokens
          raise InvalidAnalysis, "Snapshot exceeds model context"
        end
        prompt.skip_trim = true
        response =
          llm.generate(
            prompt,
            user: @report.requested_by,
            feature_name: "ask_ai_report",
            temperature: agent.temperature,
            top_p: agent.top_p,
            thinking_effort: agent.thinking_effort,
            response_format: response_format(agent),
            max_tokens: 8000,
          )
        result = JSON.parse(DiscourseAi::Completions::Llm.text_from_response(response))
        ids = asks.map(&:first)
        validate!(result, ids)
        assigned = result.fetch("subjects").flat_map { |subject| subject.fetch("ask_ids") }
        missing = ids - assigned
        if missing.present?
          result["subjects"] << {
            "name" => I18n.t("discourse_ai.ask_ai_reports.ungrouped_name"),
            "description" => I18n.t("discourse_ai.ask_ai_reports.ungrouped_description"),
            "ask_ids" => missing,
          }
        end
        result["examples"] = asks.to_h { |id, query, _| [id, query] }
        result
      end

      private

      def response_format(agent)
        properties = DiscourseAi::Agents::Bot.json_schema_properties(agent.response_format)
        {
          type: "json_schema",
          json_schema: {
            name: "ask_ai_subjects",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              required: properties.keys.map(&:to_s),
              properties:,
            },
          },
        }
      end

      def validate!(result, ids)
        unless result.is_a?(Hash) && result["summary"].is_a?(String) &&
                 result["summary"].length.between?(1, 2000)
          raise InvalidAnalysis
        end
        subjects = result["subjects"]
        unless subjects.is_a?(Array) && subjects.size.between?(1, 8)
          raise InvalidAnalysis, "Expected between 1 and 8 subjects"
        end
        subjects.each do |subject|
          unless subject.is_a?(Hash) && subject["name"].is_a?(String) &&
                   subject["name"].length.between?(1, 100) &&
                   subject["description"].is_a?(String) &&
                   subject["description"].length.between?(1, 1000) &&
                   subject["ask_ids"].is_a?(Array) && subject["ask_ids"].present? &&
                   subject["ask_ids"].all? { |id| id.is_a?(Integer) } &&
                   subject["ask_ids"].uniq.size == subject["ask_ids"].size
            raise InvalidAnalysis
          end
        end
        validate_insights!(result["insights"], ids)
        assigned = subjects.flat_map { |subject| subject["ask_ids"] }
        unknown = assigned - ids
        raise InvalidAnalysis, "Unknown IDs: #{unknown}" if unknown.present?
      end

      def validate_insights!(insights, ids)
        unless insights.is_a?(Array) && insights.size <= 3
          raise InvalidAnalysis, "Expected at most 3 insights"
        end
        insights.each do |insight|
          unless insight.is_a?(Hash) &&
                   %w[title observation suggested_action].all? { |field|
                     insight[field].is_a?(String) &&
                       insight[field].length.between?(1, field == "title" ? 100 : 1000)
                   }
            raise InvalidAnalysis, "Each insight needs a title, observation, and suggested action"
          end
          evidence = insight["ask_ids"]
          unless evidence.is_a?(Array) && evidence.size.between?(1, 3) &&
                   evidence.all? { |id| id.is_a?(Integer) && ids.include?(id) } &&
                   evidence.uniq.size == evidence.size
            raise InvalidAnalysis, "Insight evidence must reference 1 to 3 distinct supplied IDs"
          end
        end
      end
    end
  end
end

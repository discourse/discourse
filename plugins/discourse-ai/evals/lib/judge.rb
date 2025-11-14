# frozen_string_literal: true

module DiscourseAi
  module Evals
    # Evaluates model outputs using the criteria embedded in the eval.
    #
    # Today it supports the single-output flow that scores one result against a
    # rubric. It encapsulates prompt construction and rating parsing so future
    # comparison judges can reuse the same entry point.
    class Judge
      RESPONSE_FORMAT = {
        type: "json_schema",
        json_schema: {
          name: "judgeVerdict",
          schema: {
            type: "object",
            additionalProperties: false,
            required: %w[rating explanation],
            properties: {
              rating: {
                type: "integer",
                minimum: 1,
                maximum: 10,
              },
              explanation: {
                type: "string",
              },
            },
          },
        },
      }.freeze

      def initialize(eval_case:, judge_llm:)
        judge_config = eval_case.judge || {}
        @eval_case = eval_case
        @judge_llm = judge_llm
        @criteria = judge_config[:criteria].presence || judge_config[:prompt].to_s
        @pass_rating = judge_config[:pass_rating] || 10
      end

      def evaluate(result)
        prompt = build_prompt(result)
        response =
          judge_llm.to_llm.generate(
            prompt,
            user: Discourse.system_user,
            temperature: 0,
            response_format: RESPONSE_FORMAT,
          )

        parsed = parse_response(response)
        rating = parsed[:rating]
        explanation = parsed[:explanation]
        raw = parsed[:raw]

        if rating >= pass_rating
          { result: :pass, context: explanation.presence || raw }
        else
          {
            result: :fail,
            message: "LLM Rating below threshold, it was #{rating}, expecting #{pass_rating}",
            context: explanation.presence || raw,
          }
        end
      end

      private

      attr_reader :eval_case, :judge_llm, :criteria, :pass_rating

      def build_prompt(result)
        output_text, metadata = normalize_result(result)
        sections = []
        rubric_text =
          if criteria.present?
            criteria.strip
          else
            "Score the output purely on accuracy, completeness, and adherence to the task instructions."
          end

        sections << "Grading rubric:\n#{rubric_text}"
        sections << "Candidate output:\n#{output_text}"
        sections.concat(metadata)

        sections << prompt_suffix

        DiscourseAi::Completions::Prompt.new(
          "You are an expert judge evaluating LLM outputs.",
          messages: [{ type: :user, content: sections.join("\n\n") }],
        )
      end

      def normalize_result(result)
        if result.is_a?(String)
          [result, formatted_args]
        elsif result.is_a?(Hash)
          output = result[:result].to_s
          other_metadata =
            result
              .except(:result)
              .map { |key, value| "extra #{key}:\n#{format_placeholder_value(value)}" }
          [output, formatted_args + other_metadata]
        else
          [result.to_s, formatted_args]
        end
      end

      def formatted_args
        args = eval_case.args
        return [] unless args.is_a?(Hash)

        args.map { |key, value| "Source #{key}:\n#{format_placeholder_value(value)}" }
      end

      def format_placeholder_value(value)
        case value
        when Array
          value.join("\n\n")
        else
          value.to_s
        end
      end

      def prompt_suffix
        <<~SUFFIX

          Evaluate the candidate output using the criteria above. Respond with JSON matching:

          {
            "rating": <integer between 1 and 10, where 10 is perfect>,
            "explanation": "brief sentence explaining the score"
          }
        SUFFIX
      end

      def parse_response(response)
        rating = explanation = nil

        if response.respond_to?(:read_buffered_property)
          rating = response.read_buffered_property(:rating)
          explanation = response.read_buffered_property(:explanation)
          raw = response.to_s
        else
          raw_text = response.to_s
          begin
            parsed = JSON.parse(raw_text)
            rating = parsed["rating"]
            explanation = parsed["explanation"]
          rescue JSON::ParserError
            # leave rating nil
          end
          raw = raw_text
        end

        { rating: rating.to_i, explanation: explanation.to_s.strip, raw: raw }
      end
    end
  end
end

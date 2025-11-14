# frozen_string_literal: true

module DiscourseAi
  module Evals
    # Evaluates model outputs using the judge configuration embedded in the eval.
    #
    # Today it supports the single-output flow that compares one result against
    # a rubric. The class encapsulates the placeholder substitution and rating
    # parsing logic so future comparison judges can reuse the same entry point.
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
        @eval_case = eval_case
        @judge_llm = judge_llm
        @config = eval_case.judge || {}
      end

      def evaluate(result)
        prompt = build_prompt(result)

        response =
          judge_llm
            .to_llm
            .generate(
              prompt,
              user: Discourse.system_user,
              temperature: 0,
              response_format: RESPONSE_FORMAT,
            ) { |partial| structured_output = partial }

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

      attr_reader :eval_case, :judge_llm, :config

      def build_prompt(result)
        prompt = (config[:prompt] || "").dup

        if result.is_a?(String)
          prompt.sub!("{{output}}", result)
          inject_args(prompt)
        else
          prompt.sub!("{{output}}", result[:result].to_s)
          result.each { |key, value| prompt.sub!("{{#{key}}}", value.to_s) }
        end

        prompt << prompt_suffix
      end

      def inject_args(prompt)
        args = eval_case.args
        return unless args.respond_to?(:each)

        args.each { |key, value| prompt.sub!("{{#{key}}}", format_placeholder_value(value)) }
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

      def pass_rating
        config[:pass_rating] || 10
      end
    end
  end
end

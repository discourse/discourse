# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowAskQuestions < Base
        MAX_QUESTIONS = 4
        MAX_OPTIONS = 8
        MAX_TEXT_LENGTH = 500

        def self.signature
          {
            name: name,
            description:
              "Ask the workflow admin concise clarification questions and pause workflow authoring until the admin answers.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[questions],
              properties: {
                questions: {
                  type: "array",
                  minItems: 1,
                  maxItems: MAX_QUESTIONS,
                  items: {
                    type: "object",
                    additionalProperties: false,
                    required: %w[id question options],
                    properties: {
                      id: {
                        type: "string",
                        description: "Stable short identifier for this question.",
                      },
                      question: {
                        type: "string",
                        description: "The question to show to the admin.",
                      },
                      multi_select: {
                        type: "boolean",
                        description: "Whether the admin may choose more than one option.",
                      },
                      custom_allowed: {
                        type: "boolean",
                        description: "Whether the admin may type a custom answer.",
                      },
                      options: {
                        type: "array",
                        minItems: 2,
                        maxItems: MAX_OPTIONS,
                        items: {
                          type: "object",
                          additionalProperties: false,
                          required: %w[label description],
                          properties: {
                            label: {
                              type: "string",
                              description: "Short option label.",
                            },
                            description: {
                              type: "string",
                              description: "One sentence describing what this option means.",
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_ask_questions"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          questions =
            Array
              .wrap(parameters[:questions])
              .first(MAX_QUESTIONS)
              .filter_map
              .with_index { |question, index| normalize_question(question, index) }
          return error_response("At least one question is required") if questions.blank?

          { status: "waiting_for_user", questions: questions }
        end

        def chain_next_response?
          false
        end

        private

        def normalize_question(question, index)
          question = normalized_hash(question)
          text = truncate_text(question[:question])
          return if text.blank?

          options =
            Array
              .wrap(question[:options])
              .first(MAX_OPTIONS)
              .filter_map { |option| normalize_option(option) }

          {
            id: truncate_text(question[:id].presence || "question_#{index + 1}", 80),
            question: text,
            multi_select: !!question[:multi_select],
            custom_allowed: question.key?(:custom_allowed) ? !!question[:custom_allowed] : true,
            options: options,
          }
        end

        def normalize_option(option)
          option = option.is_a?(Hash) ? normalized_hash(option) : { label: option.to_s }
          label = truncate_text(option[:label])
          return if label.blank?

          { label: label, description: truncate_text(option[:description]) }
        end

        def truncate_text(text, length = MAX_TEXT_LENGTH)
          text.to_s.strip.truncate(length)
        end

        def normalized_hash(value)
          value.respond_to?(:to_h) ? value.to_h.with_indifferent_access : {}.with_indifferent_access
        end
      end
    end
  end
end

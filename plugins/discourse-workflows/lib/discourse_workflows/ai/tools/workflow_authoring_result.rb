# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowAuthoringResult < Base
        STATUSES = %w[needs_clarification proposed_patch explanation error].freeze
        RISK_LEVELS = %w[low medium high].freeze
        MAX_TEXT_LENGTH = 2000
        MISSING_PROPOSAL_OPERATIONS_MESSAGE =
          "Proposed patch results must include proposal.operations"

        def self.signature
          {
            name: name,
            description:
              "Return the final workflow authoring result to Discourse and stop the authoring turn. Use this instead of writing a JSON final answer.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[status message],
              properties: {
                status: {
                  type: "string",
                  enum: STATUSES,
                  description:
                    "Final result status: needs_clarification, proposed_patch, explanation, or error.",
                },
                message: {
                  type: "string",
                  description: "Short user-facing summary of the result.",
                },
                questions: {
                  type: "array",
                  description: "Clarification questions when status is needs_clarification.",
                  items: {
                    type: "object",
                    additionalProperties: true,
                    properties: {
                      id: {
                        type: "string",
                      },
                      question: {
                        type: "string",
                      },
                      multi_select: {
                        type: "boolean",
                      },
                      custom_allowed: {
                        type: "boolean",
                      },
                      options: {
                        type: "array",
                        items: {
                          type: "object",
                          additionalProperties: true,
                          properties: {
                            label: {
                              type: "string",
                            },
                            description: {
                              type: "string",
                            },
                          },
                        },
                      },
                    },
                  },
                },
                proposal: {
                  type: "object",
                  description:
                    "Workflow patch proposal when status is proposed_patch. Include title, summary, assumptions, risks, risk_level, and operations.",
                  additionalProperties: true,
                  properties: {
                    title: {
                      type: "string",
                    },
                    workflow_name: {
                      type: "string",
                    },
                    summary: {
                      type: "string",
                    },
                    assumptions: {
                      type: "array",
                      items: {
                        type: "string",
                      },
                    },
                    risks: {
                      type: "array",
                      items: {
                        type: "string",
                      },
                    },
                    risk_level: {
                      type: "string",
                      enum: RISK_LEVELS,
                    },
                    operations: {
                      type: "array",
                      items: {
                        type: "object",
                        additionalProperties: true,
                      },
                    },
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_authoring_result"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          normalize_response
        end

        def chain_next_response?
          false
        end

        private

        def normalize_response
          params = normalized_hash(parameters)
          proposal = normalized_hash(params[:proposal])
          operations = normalized_patch_operations(proposal[:operations])
          proposal[:operations] = operations if operations.present?

          status = params[:status].to_s
          status = "proposed_patch" if status.blank? && operations.present?

          response = {
            status: status,
            message: truncate_text(params[:message]),
            questions: normalized_questions(params[:questions]),
            proposal: json_safe(proposal),
          }

          validate_response(response)
        end

        def validate_response(response)
          if STATUSES.exclude?(response[:status])
            return error_result("Invalid workflow authoring result status")
          end

          if response[:status] == "needs_clarification" && response[:questions].blank?
            return error_result("Clarification results must include at least one question")
          end

          if response[:status] == "proposed_patch" && response.dig(:proposal, "operations").blank?
            return error_result(MISSING_PROPOSAL_OPERATIONS_MESSAGE)
          end

          response
        end

        def error_result(message)
          { status: "error", message: message, questions: [], proposal: {} }
        end

        def normalized_questions(questions)
          Array
            .wrap(questions)
            .first(WorkflowAskQuestions::MAX_QUESTIONS)
            .filter_map
            .with_index { |question, index| normalize_question(question, index) }
        end

        def normalize_question(question, index)
          question = normalized_hash(question)
          text = truncate_text(question[:question], WorkflowAskQuestions::MAX_TEXT_LENGTH)
          return if text.blank?

          options =
            Array
              .wrap(question[:options])
              .first(WorkflowAskQuestions::MAX_OPTIONS)
              .filter_map { |option| normalize_option(option) }

          {
            id:
              truncate_text(
                question[:id].presence || "question_#{index + 1}",
                WorkflowAskQuestions::MAX_TEXT_LENGTH,
              ),
            question: text,
            multi_select: !!question[:multi_select],
            custom_allowed: question.key?(:custom_allowed) ? !!question[:custom_allowed] : true,
            options: options,
          }
        end

        def normalize_option(option)
          option = option.is_a?(Hash) ? normalized_hash(option) : { label: option.to_s }
          label = truncate_text(option[:label], WorkflowAskQuestions::MAX_TEXT_LENGTH)
          return if label.blank?

          {
            label: label,
            description: truncate_text(option[:description], WorkflowAskQuestions::MAX_TEXT_LENGTH),
          }
        end

        def normalized_patch_operations(operations)
          Array
            .wrap(operations)
            .map { |operation| operation.respond_to?(:to_h) ? operation.to_h : operation }
        end

        def normalized_hash(value)
          value.respond_to?(:to_h) ? value.to_h.with_indifferent_access : {}.with_indifferent_access
        end

        def truncate_text(text, length = MAX_TEXT_LENGTH)
          text.to_s.strip.truncate(length)
        end
      end
    end
  end
end

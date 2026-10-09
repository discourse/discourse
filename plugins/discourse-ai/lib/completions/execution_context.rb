# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ExecutionContext
      attr_accessor :token_usage_tracker,
                    :work_budget,
                    :work_execution_state,
                    :generated_output,
                    :generation_event_id,
                    :generation_settled,
                    :root_reply_completed
      attr_reader :audit_logger, :structured_audit_logger, :upload_skips

      def initialize(
        token_usage_tracker: nil,
        audit_logger: nil,
        structured_audit_logger: nil,
        work_budget: nil
      )
        @token_usage_tracker = token_usage_tracker
        @work_budget = work_budget
        @audit_logger = audit_logger
        @structured_audit_logger = structured_audit_logger
        @upload_skips = []
        @preparation_state = { mutex: Mutex.new, budget: nil }
      end

      def for_new_turn
        self.class.new(
          token_usage_tracker: token_usage_tracker,
          audit_logger: audit_logger,
          structured_audit_logger: structured_audit_logger,
        )
      end

      def share_preparation_budget(budget)
        @preparation_state[:mutex].synchronize { @preparation_state[:budget] ||= budget }
      end

      def settle_generation(tokens: nil, tokenizer:, complete: true)
        return if generation_settled || !generated_output
        exposed_tokens = generated_output.size(tokenizer)
        measured_tokens = tokens.to_i > 0 ? tokens.to_i : exposed_tokens
        # Interrupted streams can report an early usage snapshot below the output already exposed.
        measured_tokens = [measured_tokens, exposed_tokens].max if !complete
        return if measured_tokens <= 0
        self.generation_settled = true
        work_budget&.debit(measured_tokens, event_id: generation_event_id)
      end
    end
  end
end

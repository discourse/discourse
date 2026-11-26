# frozen_string_literal: true

module DiscourseAi
  module Completions
    module PromptHints
      TOKEN_BUDGET_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The turn work allowance has been reached — no further tool calls are available.]
        Answer directly from what you have; do not spend tokens deliberating at length.
        Provide your final response now using the information already gathered.
        Do not describe additional tool calls or future work as though you will perform them.
        If the task is not fully complete, clearly state what was accomplished
        and what still needs to be done so the user can continue in a follow-up message.
      TEXT
      TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The tool invocation limit has been reached — no further tool calls are available.]
        Answer directly from what you have; do not spend tokens deliberating at length.
        Provide your final response now using the information already gathered.
        If the evidence is insufficient, say so instead of attempting another tool call.
      TEXT
      COMPLETION_LIMIT_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The shared completion safety limit has been reached — no further tool calls are available.]
        Answer directly from what you have; do not spend tokens deliberating at length.
        Provide one final response using the information already gathered.
      TEXT
      MCP_FAILURE_FINAL_ANSWER_HINT = <<~TEXT.strip
        [Repeated MCP tool failures have stopped further tool calls for this turn.]
        Provide a concise final answer explaining the actual error and what remains undone.
        Do not claim success without successful tool evidence. Do not repeat or promise more calls.
      TEXT
      LEGACY_BUDGET_EXHAUSTED_HINT = <<~TEXT.strip
        [Turn budget exhausted — you cannot call any more tools.]
        Answer directly from what you have; do not spend tokens deliberating at length.
        Provide your final response using the information already gathered.
        If the task is not fully complete, clearly state what was accomplished
        and what still needs to be done so the user can continue in a follow-up message.
      TEXT
      BUDGET_EXHAUSTED_HINT = TOKEN_BUDGET_FINAL_ANSWER_HINT
      TRANSIENT_TOKEN_BUDGET_HINTS = [
        TOKEN_BUDGET_FINAL_ANSWER_HINT,
        TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT,
        COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        MCP_FAILURE_FINAL_ANSWER_HINT,
        LEGACY_BUDGET_EXHAUSTED_HINT,
      ].freeze

      # Older saved prompts have only the hint text. An attributed user can quote it verbatim.
      def self.budget_hint?(message)
        message[:type] == :user && message[:id].blank? && message[:name].blank? &&
          TRANSIENT_TOKEN_BUDGET_HINTS.include?(message[:content])
      end
    end
  end
end

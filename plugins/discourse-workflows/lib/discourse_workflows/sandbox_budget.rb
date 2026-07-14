# frozen_string_literal: true

module DiscourseWorkflows
  class SandboxBudget
    TOTAL_BUDGET_MS = 1_000
    CONTEXT_KEY = "__sandbox_elapsed_ms"

    def initialize(context = nil, budget_ms: TOTAL_BUDGET_MS)
      @context = context
      @budget_ms = budget_ms
      @elapsed_ms = 0
    end

    def charge!(elapsed_ms)
      total = elapsed_ms + current_elapsed_ms
      persist_elapsed_ms(total)

      return if total <= @budget_ms

      raise JsSandbox::BudgetExceededError,
            "Sandbox execution time exceeded #{@budget_ms}ms for this workflow"
    end

    def current_elapsed_ms
      if @context
        @context.fetch(CONTEXT_KEY, 0).to_f
      else
        @elapsed_ms
      end
    end

    private

    def persist_elapsed_ms(total)
      if @context
        @context[CONTEXT_KEY] = total.round(3)
      else
        @elapsed_ms = total
      end
    end
  end
end

# frozen_string_literal: true

class ProblemCheck::AiAskAiExternalSource < ProblemCheck
  self.priority = "high"
  self.perform_every = 1.hour
  self.targets = -> { SiteSetting.ai_ask_ai_external_sources.to_s.split("|").map(&:to_i) }

  LOOKBACK_HOURS = 6
  MIN_SEARCHES = 5
  SKIPPED_RATE_THRESHOLD = 0.5

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_ask_ai_enabled

    ai_tool = AiTool.find_by(id: target, enabled: true)
    return no_problem if ai_tool.nil?

    counts =
      DiscourseAi::Discoveries::ExternalSource.outcome_counts(ai_tool.id, hours: LOOKBACK_HOURS)
    searches = counts.values.sum
    skipped = searches - counts["succeeded"]
    return no_problem if searches < MIN_SEARCHES
    return no_problem if skipped.to_f / searches < SKIPPED_RATE_THRESHOLD

    details = {
      target: ai_tool.id,
      tool_name: ai_tool.name,
      skipped:,
      searches:,
      timed_out: counts["timed_out"],
      failed: counts["failed"],
      busy: counts["busy"],
      hours: LOOKBACK_HOURS,
    }
    problem(ai_tool, override_data: details, details:)
  end
end

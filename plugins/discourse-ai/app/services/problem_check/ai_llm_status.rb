# frozen_string_literal: true

class ProblemCheck::AiLlmStatus < ProblemCheck
  self.priority = "high"
  self.perform_every = 6.hours
  self.targets = -> { LlmModel.in_use.pluck(:id) }

  LOOKBACK_WINDOW = 6.hours
  MIN_TOTAL_CALLS = 5
  MIN_FAILED_CALLS = 3
  FAILURE_RATE_THRESHOLD = 0.5

  def self.problem_details(model, failed_calls, total_calls, lookback_hours)
    {
      target: model.id,
      model_name: model.display_name,
      failed_calls: failed_calls,
      total_calls: total_calls,
      count: lookback_hours,
    }
  end

  def self.fast_track_problem!(model, failed_calls, lookback_hours)
    return if model.blank? || model.new_record?

    tracker = ProblemCheckTracker[:ai_llm_status, model.id]
    details = problem_details(model, failed_calls, failed_calls, lookback_hours)
    tracker.problem!(details: details)
  end

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled

    model = LlmModel.in_use.find_by(id: target)

    return no_problem if model.blank?
    return no_problem if model.seeded?

    total_calls, failed_calls = audit_log_counts(model)

    return no_problem if total_calls < MIN_TOTAL_CALLS
    return no_problem if failed_calls < MIN_FAILED_CALLS
    return no_problem if failure_rate(total_calls, failed_calls) < FAILURE_RATE_THRESHOLD

    details =
      self.class.problem_details(model, failed_calls, total_calls, (LOOKBACK_WINDOW / 1.hour))

    problem(model, override_data: details, details: details)
  end

  private

  def audit_log_counts(model)
    counts = DB.query_single(<<~SQL, llm_id: model.id, since: LOOKBACK_WINDOW.ago)
        SELECT
          COUNT(*) AS total_calls,
          SUM(
            CASE
              WHEN response_status IS NOT NULL THEN
                CASE WHEN response_status NOT BETWEEN 200 AND 299 THEN 1 ELSE 0 END
              ELSE
                CASE WHEN COALESCE(response_tokens, 0) <= 0 THEN 1 ELSE 0 END
            END
          ) AS failed_calls
        FROM ai_api_audit_logs
        WHERE llm_id = :llm_id
          AND created_at >= :since
      SQL

    total_calls = counts[0].to_i
    failed_calls = counts[1].to_i

    [total_calls, failed_calls]
  end

  def failure_rate(total_calls, failed_calls)
    return 0.0 if total_calls.to_i.zero?

    failed_calls.to_f / total_calls
  end
end

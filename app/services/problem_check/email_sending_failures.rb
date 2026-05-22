# frozen_string_literal: true

class ProblemCheck::EmailSendingFailures < ProblemCheck
  self.priority = "low"
  self.perform_every = 1.hour

  LOOKBACK_WINDOW = 24.hours

  def call
    # De-duplicate with ProblemCheck::FailingEmails so we only show one
    # admin alert for the same SMTP incident when retry jobs are already failing.
    return no_problem if failing_email_job_count > 0
    return no_problem if failed_send_count == 0

    problem
  end

  private

  def failed_send_count
    @failed_delivery_count ||=
      SkippedEmailLog
        .where(reason_type: SkippedEmailLog.reason_types[:custom])
        .where("created_at >= ?", LOOKBACK_WINDOW.ago)
        .count
  end

  def failing_email_job_count
    @failing_email_job_count ||= Jobs.num_email_retry_jobs.to_i
  end

  def translation_data
    { count: failed_send_count }
  end
end

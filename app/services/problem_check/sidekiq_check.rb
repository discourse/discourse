# frozen_string_literal: true

class ProblemCheck::SidekiqCheck < ProblemCheck
  self.priority = "low"

  def call
    return problem("dashboard.sidekiq_warning") if jobs_in_queue? && !jobs_performed_recently?
    return problem("dashboard.queue_size_warning", queue_size: Jobs.queued) if massive_queue?

    no_problem
  end

  private

  def massive_queue?
    Jobs.queued >= 100_000
  end

  def jobs_in_queue?
    Jobs.queued > 0
  end

  def jobs_performed_recently?
    Jobs.last_job_performed_at.present? && Jobs.last_job_performed_at > 2.minutes.ago
  end
end

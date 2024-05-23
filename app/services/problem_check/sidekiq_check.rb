# frozen_string_literal: true

class ProblemCheck::SidekiqCheck < ProblemCheck
  self.priority = "low"

  def call
    if jobs_in_queue? && !jobs_performed_recently?
      return problem(override_key: "dashboard.problem.sidekiq")
    end

    if massive_queue?
      return(
        problem(
          override_key: "dashboard.problem.queue_size",
          override_data: {
            queue_size: Jobs.queued,
          },
        )
      )
    end

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

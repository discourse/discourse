# frozen_string_literal: true

class ProblemCheck::FailingEmails < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if failed_job_count.to_i == 0

    problem
  end

  private

  def failed_job_count
    @failed_job_count ||= Jobs.num_email_retry_jobs
  end

  def translation_data
    { num_failed_jobs: failed_job_count }
  end
end

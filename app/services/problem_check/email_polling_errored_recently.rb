# frozen_string_literal: true

class ProblemCheck::EmailPollingErroredRecently < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if polling_error_count.to_i == 0

    problem
  end

  private

  def polling_error_count
    @polling_error_count ||= Jobs::PollMailbox.errors_in_past_24_hours
  end

  def translation_data
    { count: polling_error_count }
  end
end

# frozen_string_literal: true

class ProblemCheck::StarttlsDisabled < ProblemCheck
  self.priority = "high"

  def call
    if GlobalSetting.smtp_enable_start_tls
      no_problem
    else
      problem
    end
  end
end

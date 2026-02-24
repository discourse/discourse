# frozen_string_literal: true

class ProblemCheck::QqMailSmtp < ProblemCheck
  self.priority = "low"

  def call
    smtp_address = ActionMailer::Base.smtp_settings[:address].to_s.downcase
    return no_problem if !smtp_address.match?(/\A(?:qq\.com|.+\.qq\.com)\z/)

    problem
  end

  private

  def translation_data
    { smtp_address: ActionMailer::Base.smtp_settings[:address] }
  end
end

# frozen_string_literal: true

class ProblemCheck::MissingAwsSnsTopicArn < ProblemCheck
  self.priority = "low"

  SES_SMTP_PATTERN = /(email-smtp|amazonses).*amazonaws\.com\z/i

  def call
    return no_problem if SiteSetting.aws_sns_topic_arn_allowlist.present?
    return no_problem unless smtp_looks_like_ses?

    problem
  end

  private

  def smtp_looks_like_ses?
    ActionMailer::Base.smtp_settings[:address].to_s.match?(SES_SMTP_PATTERN)
  end
end

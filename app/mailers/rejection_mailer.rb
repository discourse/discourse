require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(from, body, error)
    build_email(from, template: 'email_error_notification', error: "#{error.message}\n\n#{error.backtrace.join("\n")}", source: body)
  end

  def send_trust_level(from, body)
    build_email(from, template: 'email_reject_trust_level')
  end
end

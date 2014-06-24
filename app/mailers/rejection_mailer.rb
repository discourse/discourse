require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(from, body, template, error)
    build_email(from, from: from, template: template, error: error, source: body)
  end

  def send_trust_level(from, template)
    build_email(from, template: 'email_reject_trust_level')
  end
end

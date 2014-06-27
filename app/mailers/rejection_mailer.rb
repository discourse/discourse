require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(from, body, to_address, template)
    build_email(from, template: "system_messages.#{template}", source: body, destination: to_address)
  end

  def send_trust_level(from, template)
    build_email(from, template: 'email_reject_trust_level')
  end
end

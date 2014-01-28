require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(from, body)
    build_email(from, template: 'email_reject_notification', from: from, body: body)
  end
end

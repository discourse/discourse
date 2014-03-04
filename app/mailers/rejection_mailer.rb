require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(from, body)
    build_email(from, template: 'email_reject_notification', from: from, body: body)
  end
<<<<<<< HEAD
=======

  def send_trust_level(from, body, to)
    build_email(from, template: 'email_reject_trust_level', to: to)
  end
>>>>>>> upstream/master
end

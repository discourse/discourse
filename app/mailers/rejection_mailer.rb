require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_rejection(message_from, message_body, message_subject, forum_address, template)
    build_email(message_from,
                template: "system_messages.#{template}",
                source: message_body,
                former_title: message_subject,
                destination: forum_address)
  end

end

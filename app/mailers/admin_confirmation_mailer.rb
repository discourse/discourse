require_dependency 'email/message_builder'

class AdminConfirmationMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_email(to_address, target_username, token)
    build_email(
      to_address,
      template: 'admin_confirmation_mailer',
      target_username: target_username,
      admin_confirm_url: confirm_admin_url(token: token, host: Discourse.base_url)
    )
  end
end

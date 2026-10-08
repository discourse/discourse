# frozen_string_literal: true

class EmailLoginCodeMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  layout "email_template"

  def send_code(email, code, password_reset: false)
    build_email(
      email,
      template: password_reset ? "password_reset_code_mailer" : "email_login_code_mailer",
      code: code,
      minutes: EmailLoginCode::VALID_FOR.in_minutes.to_i,
    )
  end
end

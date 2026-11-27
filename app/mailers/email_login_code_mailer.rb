# frozen_string_literal: true

class EmailLoginCodeMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  layout "email_template"

  TEMPLATES = {
    login: "email_login_code_mailer",
    password_reset: "password_reset_code_mailer",
    session_confirmation: "session_confirmation_code_mailer",
  }.freeze

  def send_code(email, code, password_reset: false, purpose: nil, user: nil)
    resolved_purpose =
      if purpose
        purpose.to_sym
      elsif password_reset
        :password_reset
      else
        :login
      end

    opts = {
      template: TEMPLATES.fetch(resolved_purpose),
      code: code,
      minutes: EmailLoginCode::VALID_FOR.in_minutes.to_i,
    }
    if user
      opts[:locale] = user.effective_locale
      opts[:recipient_user] = user
      I18n.with_locale(user.effective_locale) { build_email(email, opts) }
    else
      build_email(email, opts)
    end
  end
end

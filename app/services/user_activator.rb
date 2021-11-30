# frozen_string_literal: true

class UserActivator
  attr_reader :user, :request, :session, :cookies, :message

  def initialize(user, request, session, cookies)
    @user = user
    @session = session
    @cookies = cookies
    @request = request
    @message = nil
  end

  def start
  end

  def finish
    @message = activator.activate
  end

  def success_message
    activator.success_message
  end

  private

  def activator
    factory.new(user, request, session, cookies)
  end

  def factory
    invite = Invite.find_by(email: Email.downcase(@user.email))

    if !user.active?
      EmailActivator
    elsif SiteSetting.must_approve_users? && !(invite.present? && invite.redeemable?)
      ApprovalActivator
    else
      LoginActivator
    end
  end

end

class ApprovalActivator < UserActivator
  def activate
    success_message
  end

  def success_message
    I18n.t("login.wait_approval")
  end
end

class EmailActivator < UserActivator
  def activate
    email_token = user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
    EmailToken.enqueue_signup_email(email_token)
    success_message
  end

  def success_message
    I18n.t("login.activate_email", email: Rack::Utils.escape_html(user.email))
  end
end

class LoginActivator < UserActivator
  include CurrentUser

  def activate
    log_on_user(user)
    user.enqueue_welcome_message('welcome_user')
    success_message
  end

  def success_message
    I18n.t("login.active")
  end
end

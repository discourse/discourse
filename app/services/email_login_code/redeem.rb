# frozen_string_literal: true

class EmailLoginCode::Redeem
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract

  model :login_code
  policy :code_matches
  policy :can_register_new_account

  lock(:email) do
    transaction do
      step :consume_code
      model :user, :ensure_user
    end
  end

  only_if(:user_requires_activation?) do
    step :activate_user
    step :send_welcome_message
  end

  private

  def fetch_login_code(params:)
    EmailLoginCode.active.for_email(params.email).first
  end

  def code_matches(login_code:, params:)
    login_code.verify(params.code)
  end

  def can_register_new_account(params:)
    return true if User::Action::FindByEmail.call(email: params.email).present?

    SiteSetting.allow_new_registrations && !SiteSetting.invite_only &&
      !SiteSetting.require_invite_code
  end

  def consume_code(login_code:)
    login_code.consume!
  end

  def ensure_user(params:, ip_address:)
    User::Action::FindByEmail.call(email: params.email) ||
      User::Action::CreateFromVerifiedEmail.call(email: params.email, ip_address: ip_address)
  end

  def user_requires_activation?(user:)
    !user.active?
  end

  def activate_user(user:)
    user.activate
  end

  def send_welcome_message(user:)
    user.enqueue_welcome_message("welcome_user")
  end
end

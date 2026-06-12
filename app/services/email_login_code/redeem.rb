# frozen_string_literal: true

class EmailLoginCode::Redeem
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract do
    attribute :user_fields

    before_validation { self.user_fields = user_fields.to_h.stringify_keys if user_fields.present? }
  end

  model :login_code
  policy :code_matches
  model :existing_user, :fetch_existing_user, optional: true
  policy :can_register_new_account
  policy :required_fields_provided

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

  def fetch_existing_user(params:)
    User::Action::FindByEmail.call(email: params.email)
  end

  def can_register_new_account(existing_user:)
    return true if existing_user.present?

    SiteSetting.allow_new_registrations && !SiteSetting.invite_only &&
      !SiteSetting.require_invite_code
  end

  def required_fields_provided(existing_user:, params:)
    return true if existing_user.present?

    values = params.user_fields.presence || {}
    UserField
      .required
      .pluck(:id)
      .all? do |field_id|
        value = values[field_id.to_s]
        value.present? && value != "false"
      end
  end

  def consume_code(login_code:)
    login_code.consume!
  end

  def ensure_user(existing_user:, params:, ip_address:)
    existing_user ||
      User::Action::CreateFromVerifiedEmail.call(
        email: params.email,
        ip_address: ip_address,
        user_fields: params.user_fields,
      )
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

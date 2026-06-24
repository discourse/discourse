# frozen_string_literal: true

class EmailLoginCode::Redeem
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract do
    attribute :user_fields

    before_validation do
      # Only hash-like input can carry field values; anything else (a stray
      # string/array) becomes an empty set so it fails as a missing field
      # rather than raising during normalization.
      self.user_fields =
        (
          if user_fields.is_a?(Hash) || user_fields.is_a?(ActionController::Parameters)
            user_fields.to_h.stringify_keys
          else
            {}
          end
        )
    end
  end

  model :login_code
  policy :code_matches
  model :existing_user, :fetch_existing_user, optional: true
  policy :email_available_for_new_account
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
    User.real.where(staged: false).with_email(params.email).first
  end

  # Login matches on the exact address only, but a code's address can still
  # belong to an existing account once normalized (e.g. a Gmail alias). Such a
  # code can neither log in nor create an account, so it's treated as invalid
  # (via the controller's generic failure) rather than leaking a reason.
  def email_available_for_new_account(existing_user:, params:)
    return true if existing_user.present?

    User::Action::FindByEmail.call(email: params.email).blank?
  end

  def can_register_new_account(existing_user:, params:)
    return true if existing_user.present?

    # Mirrors EmailLoginCode::Request#deliverable? so account creation enforces
    # the same gates as the code request, even for a code issued before an
    # address was blocked or one created outside the request service.
    SiteSetting.allow_new_registrations && !SiteSetting.invite_only &&
      !SiteSetting.require_invite_code && EmailValidator.allowed?(params.email) &&
      !ScreenedEmail.should_block?(params.email)
  end

  def required_fields_provided(existing_user:, params:)
    return true if existing_user.present?

    values = params.user_fields.presence || {}
    # Only the fields shown at signup can be collected here (the UI and
    # CreateFromVerifiedEmail both use show_on_signup); requiring a hidden field
    # would make passwordless signup impossible to complete.
    UserField
      .required
      .where(show_on_signup: true)
      .pluck(:id)
      .all? do |field_id|
        value = values[field_id.to_s]
        value.present? && value != "false"
      end
  end

  def consume_code(login_code:)
    # consume! is atomic; if it lost a race with a concurrent redemption the
    # code is already spent, so this redemption must not log anyone in.
    fail!("code already redeemed") unless login_code.consume!
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
    # Don't welcome accounts that can't access the forum yet (e.g. awaiting
    # approval under must_approve_users), matching the normal signup path.
    return if !user.guardian.can_access_forum?

    user.enqueue_welcome_message("welcome_user")
  end
end

# frozen_string_literal: true

class EmailLoginCode::Redeem
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract do
    attribute :user_fields
    attribute :name, :string
    attribute :password, :string
    attribute :username, :string
    attribute :username_required, :boolean, default: false
    attribute :new_account_required, :boolean, default: false

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
      self.name = name.to_s.strip.presence
      self.username = username.to_s.strip.presence
    end

    validates :name, length: { maximum: 255 }
    validates :password, length: { maximum: User.max_password_length }, allow_nil: true
  end

  model :login_code
  policy :code_matches
  model :existing_user, :fetch_existing_user, optional: true
  policy :new_account_available
  policy :email_available_for_new_account
  policy :can_register_new_account
  policy :can_register_from_ip
  policy :required_username_provided
  policy :username_allowed
  policy :required_fields_provided
  policy :required_full_name_provided

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
    EmailLoginCode.login.active.for_email(params.email).first
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
  def new_account_available(existing_user:, params:)
    !params.new_account_required || existing_user.blank?
  end

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

  def can_register_from_ip(existing_user:, ip_address:)
    existing_user.present? || !SpamHandler.should_prevent_registration_from_ip?(ip_address)
  end

  def required_username_provided(existing_user:, params:)
    existing_user.present? || !params.username_required || params.username.present?
  end

  def username_allowed(existing_user:, params:)
    return true if existing_user.present? || params.username.blank?

    !User.reserved_username?(params.username) &&
      !UsernameValidator.clashing_with_existing_route?(params.username)
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

  def required_full_name_provided(existing_user:, params:)
    return true if existing_user.present?

    !Site.full_name_required_for_signup || params.name.present?
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
        name: params.name,
        password: params.password,
        username: params.username,
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

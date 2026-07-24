# frozen_string_literal: true

class EmailLoginCode::Request
  include Service::Base

  params do
    attribute :email, :string

    before_validation { self.email = email.to_s.strip.downcase }

    validates :email,
              presence: true,
              length: {
                maximum: 513,
              },
              format: {
                with: EmailAddressValidator.email_regex,
              }
  end

  model :user, optional: true
  only_if(:existing_account?) { step :trigger_before_email_login }

  only_if(:deliverable?) do
    model :login_code, :generate_login_code
    step :send_login_code_email
  end

  private

  def fetch_user(params:)
    User.real.where(staged: false).with_email(params.email).first
  end

  def existing_account?(user:)
    user.present?
  end

  def trigger_before_email_login(user:)
    DiscourseEvent.trigger(:before_email_login, user)
  end

  def deliverable?(user:, params:)
    return true if user.present?
    return if !SiteSetting.allow_new_registrations
    return if SiteSetting.invite_only
    return if SiteSetting.require_invite_code
    return if !EmailValidator.allowed?(params.email)
    return if ScreenedEmail.should_block?(params.email)
    # Login matches on the exact address, but a new account can't be created for
    # an email that already belongs to someone once normalized, so don't send a
    # code that could never be redeemed into an account.
    return if User::Action::FindByEmail.call(email: params.email)

    true
  end

  def generate_login_code(params:)
    EmailLoginCode.generate!(email: params.email)
  end

  def send_login_code_email(login_code:)
    Jobs.enqueue(:send_email_login_code, to_address: login_code.email, code: login_code.code)
  end
end

# frozen_string_literal: true

class Invite::RequestEmailCode
  include Service::Base

  params do
    attribute :invite_key, :string
    attribute :email, :string

    before_validation do
      self.invite_key = invite_key.to_s.strip
      self.email = email.to_s.strip.downcase
    end

    validates :invite_key, presence: true

    def email_for(invite)
      invite.email.presence || email
    end
  end

  model :invite
  policy :email_can_redeem_invite
  policy :can_register_from_ip
  only_if(:existing_account?) { step :trigger_before_email_login }
  model :login_code, :generate_login_code
  step :send_login_code_email

  private

  def fetch_invite(params:)
    invite = Invite.find_by(invite_key: params.invite_key)
    invite if invite&.redeemable?
  end

  def email_can_redeem_invite(invite:, params:)
    email = params.email_for(invite)
    return if !EmailAddressValidator.valid_value?(email)
    return if invite.email.present? && !invite.email_matches?(email)
    return if invite.domain.present? && !invite.domain_matches?(email)
    return true if User.real.where(staged: false).with_email(email).exists?
    return if !EmailValidator.allowed?(email)
    return if ScreenedEmail.should_block?(email)

    true
  end

  def can_register_from_ip(invite:, params:, ip_address:)
    email = params.email_for(invite)
    return true if User.real.where(staged: false).with_email(email).exists?

    !SpamHandler.should_prevent_registration_from_ip?(ip_address)
  end

  def existing_account?(invite:, params:)
    User.real.where(staged: false).with_email(params.email_for(invite)).exists?
  end

  def trigger_before_email_login(invite:, params:)
    user = User.real.where(staged: false).with_email(params.email_for(invite)).first
    DiscourseEvent.trigger(:before_email_login, user)
  end

  def generate_login_code(invite:, params:)
    EmailLoginCode.generate!(email: params.email_for(invite))
  end

  def send_login_code_email(login_code:)
    Jobs.enqueue(:send_email_login_code, to_address: login_code.email, code: login_code.code)
  end
end

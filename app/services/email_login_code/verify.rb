# frozen_string_literal: true

class EmailLoginCode::Verify
  include Service::Base

  params do
    attribute :email, :string
    attribute :code, :string

    before_validation do
      self.email = email.to_s.strip.downcase
      self.code = code.to_s.strip
    end

    validates :email, presence: true, format: { with: EmailAddressValidator.email_regex }
    validates :code, presence: true, format: { with: /\A\d{#{EmailLoginCode::CODE_LENGTH}}\z/o }
  end

  model :login_code
  policy :code_matches
  model :user, optional: true

  private

  def fetch_login_code(params:)
    EmailLoginCode.active.for_email(params.email).first
  end

  def code_matches(login_code:, params:)
    login_code.verify(params.code)
  end

  def fetch_user(params:)
    User.real.where(staged: false).with_email(params.email).first
  end
end

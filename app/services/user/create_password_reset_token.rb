# frozen_string_literal: true

class User::CreatePasswordResetToken
  include Service::Base

  params do
    attribute :code, :string

    before_validation { self.code = code.to_s.strip }

    validates :code, presence: true, format: { with: /\A\d{#{EmailLoginCode::CODE_LENGTH}}\z/o }
  end

  model :login_code
  policy :code_matches
  model :user
  policy :can_write

  transaction do
    policy :consume_code
    model :email_token, :create_email_token
  end

  private

  def fetch_login_code(login_code_id:)
    EmailLoginCode.password_reset.active.find_by(id: login_code_id)
  end

  def code_matches(login_code:, params:)
    login_code.verify(params.code)
  end

  def fetch_user(user_id:, login_code:)
    user = User.real.where(staged: false).find_by(id: user_id)
    user if user&.email&.casecmp?(login_code.email)
  end

  def can_write(user:)
    !Discourse.staff_writes_only_mode? || user.staff?
  end

  def consume_code(login_code:)
    login_code.consume!
  end

  def create_email_token(user:)
    user.email_tokens.create(email: user.email, scope: EmailToken.scopes[:password_reset])
  end
end

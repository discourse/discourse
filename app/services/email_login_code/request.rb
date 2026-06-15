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

  # The code only ever logs an existing user in, so a code is generated and
  # emailed only when the address matches a real account. Unknown addresses
  # still get a successful (empty) response, so the endpoint can't be used to
  # probe whether an account exists.
  only_if(:existing_account?) do
    step :trigger_before_email_login
    model :login_code, :generate_login_code
    step :send_login_code_email
  end

  private

  def fetch_user(params:)
    User::Action::FindByEmail.call(email: params.email)
  end

  def existing_account?(user:)
    user.present?
  end

  def trigger_before_email_login(user:)
    DiscourseEvent.trigger(:before_email_login, user)
  end

  def generate_login_code(params:, ip_address:)
    EmailLoginCode.generate!(email: params.email, requested_ip: ip_address)
  end

  def send_login_code_email(login_code:)
    Jobs.enqueue(:send_email_login_code, to_address: login_code.email, code: login_code.code)
  end
end

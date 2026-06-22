# frozen_string_literal: true

class EmailLoginCode::Redeem
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract

  model :login_code
  policy :code_matches
  model :user, :fetch_user
  step :consume_code
  only_if(:user_requires_activation?) { step :activate_user }

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

  def consume_code(login_code:)
    # consume! is atomic; if it lost a race with a concurrent redemption the
    # code is already spent, so this redemption must not log anyone in.
    fail!("code already redeemed") unless login_code.consume!
  end

  def user_requires_activation?(user:)
    !user.active?
  end

  def activate_user(user:)
    user.activate
  end
end

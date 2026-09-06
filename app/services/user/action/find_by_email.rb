# frozen_string_literal: true

class User::Action::FindByEmail < Service::ActionBase
  option :email

  def call
    users.with_email(email).first || normalized_email_match
  end

  private

  def users
    User.real.where(staged: false)
  end

  def normalized_email_match
    return if !SiteSetting.normalize_emails

    normalized_email = UserEmail.normalize(email)
    return if normalized_email.blank?

    users.joins(:user_emails).where(user_emails: { normalized_email: normalized_email }).first
  end
end

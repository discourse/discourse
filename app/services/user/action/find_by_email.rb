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

    local_part, domain = email.split("@", 2)
    return if local_part.blank? || domain.blank?

    normalized_email = "#{local_part.gsub(".", "").gsub(/\+.*/, "")}@#{domain}"
    users.joins(:user_emails).where(user_emails: { normalized_email: normalized_email }).first
  end
end

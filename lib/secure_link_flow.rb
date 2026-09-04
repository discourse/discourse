# frozen_string_literal: true

class SecureLinkFlow
  EXPIRY = 10.minutes
  PURPOSES = %i[
    account_activation
    admin_confirmation
    associate_account
    email_login
    email_update_new
    email_update_old
    invite
    one_time_password
    password_reset
    unsubscribe
  ].to_set.freeze

  def initialize(server_session)
    @server_session = server_session
  end

  def stage(purpose, credential, expires: EXPIRY)
    @server_session.set(key(purpose), credential, expires:)
  end

  def credential(purpose)
    @server_session[key(purpose)]
  end

  def claim(purpose)
    @server_session.getdel(key(purpose))
  end

  def clear(purpose)
    @server_session.delete(key(purpose))
  end

  private

  def key(purpose)
    if !PURPOSES.include?(purpose)
      raise ArgumentError, "unknown secure link purpose"
    end

    "secure-link-#{purpose.to_s.dasherize}"
  end
end

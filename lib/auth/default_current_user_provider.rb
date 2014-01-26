require_dependency "auth/current_user_provider"

class Auth::DefaultCurrentUserProvider < Auth::CurrentUserProvider

  TOKEN_COOKIE ||= "_t"

  # our current user, return nil if none is found
  def current_user
    auth_token = @request.cookies[TOKEN_COOKIE]
    if auth_token && auth_token.length == 32
      User.where(auth_token: auth_token).first
    end
  end

  def log_on_user(user, session, cookies)
    unless user.auth_token && user.auth_token.length == 32
      user.auth_token = SecureRandom.hex(16)
      user.save!
    end
    cookies.permanent[TOKEN_COOKIE] = { value: user.auth_token, httponly: true }
    make_developer_admin(user)
    @env[CURRENT_USER_KEY] = user
  end

  def make_developer_admin(user)
    if  user.active? &&
        !user.admin &&
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(user.email)
      user.update_column(:admin, true)
    end
  end

  def log_off_user(session, cookies)
    cookies[TOKEN_COOKIE] = nil
  end

  def has_auth_cookie?
    cookie = @request.cookies[TOKEN_COOKIE]
    !cookie.nil? && cookie.length == 32
  end
end

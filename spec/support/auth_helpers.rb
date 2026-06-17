# frozen_string_literal: true

# Authentication for specs: the test current-user provider, cookie/request
# helpers, and the impersonation env flag.

# we need this env var to ensure that we can impersonate in test
# this enable integration_helpers sign_in helper
ENV["DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE"] = "1"

# Wired up in the `before(:suite)` hook via `Discourse.current_user_provider=`.
class TestCurrentUserProvider < Auth::DefaultCurrentUserProvider
  def log_on_user(user, session, cookies, opts = {})
    # Try using the main session as `session` sometimes is a server session
    (cookies.try(:request).try(:session) || session)[:current_user_id] = user.id
    super
  end

  def log_off_user(session, cookies, push_subscription: nil)
    # Try using the main session as `session` sometimes is a server session
    (cookies.try(:request).try(:session) || session).delete(:current_user_id)
    super
  end
end

module AuthHelpers
  def create_request_env(path: nil)
    env =
      Rails.application.env_config.dup.merge("rack.session" => ActionController::TestSession.new)
    env.merge!(Rack::MockRequest.env_for(path)) if path
    env
  end

  def create_auth_cookie(
    token:,
    user_id: nil,
    username: nil,
    trust_level: nil,
    issued_at: Time.current
  )
    data = {
      token: token,
      user_id: user_id,
      username: username,
      trust_level: trust_level,
      issued_at: issued_at.to_i,
    }
    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    jar.encrypted[:_t] = { value: data }
    CGI.escape(jar[:_t])
  end

  # Mints a signed `_t` auth cookie for a user entirely in-process, with no HTTP
  # or Rack request. `UserAuthToken.generate!` is the same model method the auth
  # provider calls in `log_on_user`, and `create_auth_cookie` encrypts the
  # payload exactly as the provider's `set_auth_cookie!` does. The payload mirrors
  # production's, including `username`, because the request tracker reads the
  # username straight from the cookie to attribute browser pageviews rather than
  # looking the user up.
  def auth_cookie_for(user)
    token = UserAuthToken.generate!(user_id: user.id, staff: user.staff?)

    create_auth_cookie(
      token: token.unhashed_auth_token,
      user_id: user.id,
      username: user.username,
      trust_level: user.trust_level,
    )
  end

  def decrypt_auth_cookie(cookie)
    ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create,
      { _t: cookie },
    ).encrypted[
      :_t
    ].with_indifferent_access
  end

  # this takes a string and returns a copy where 2 different
  # characters are swapped.
  # e.g.
  #   swap_2_different_characters("abc") => "bac"
  #   swap_2_different_characters("aac") => "caa"
  def swap_2_different_characters(str)
    swap1 = 0
    swap2 = str.split("").find_index { |c| c != str[swap1] }
    # if the string is made up of 1 character
    return str if !swap2
    str = str.dup
    str[swap1], str[swap2] = str[swap2], str[swap1]
    str
  end
end

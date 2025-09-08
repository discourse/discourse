# frozen_string_literal: true

class ActionDispatch::Session::DiscourseCookieStore < ActionDispatch::Session::CookieStore
  def initialize(app, options = {})
    super(app, options)
  end

  # By default, Rack/Rails will include the session cookie in every response,
  # even if its content hasn't changed. This makes race conditions very likely when
  # multiple requests are made in parallel
  def commit_session?(request, session, options)
    super(request, session, options) && session_has_changed?(request, session)
  end

  private

  def set_cookie(request, session_id, cookie)
    if Hash === cookie
      cookie[:secure] = true if SiteSetting.force_https
      unless SiteSetting.same_site_cookies == "Disabled"
        cookie[:same_site] = SiteSetting.same_site_cookies
      end
    end
    cookie_jar(request)[@key] = cookie
  rescue ActionDispatch::Cookies::CookieOverflow
    Rails.logger.error("Cookie overflow occurred for #{@key}: #{request.session.to_h.inspect}")
    raise
  end

  def session_has_changed?(request, session)
    _, original_session = load_session(request)
    new_session = session.to_hash
    original_session != new_session
  end
end

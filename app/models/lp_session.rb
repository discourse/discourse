class LpSession
  SESSION_COOKIE_NAME = ENV['MAIN_SITE_COOKIE_NAME']

  class << self
    def lp_user_id_from_cookie(cookies)
      cookie = cookies[SESSION_COOKIE_NAME]
      if cookie.present?
        # need to decrypt and verify session cookie
        # to check if use is logged in on lessonplanet.com ain site.
        unescaped_content = URI.unescape(cookie)
        secret_key_base   = ENV['SECRET_KEY_BASE']
        key_generator     = ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000)
        key_generator     = ActiveSupport::CachingKeyGenerator.new(key_generator)
        secret            = key_generator.generate_key('encrypted cookie')
        sign_secret       = key_generator.generate_key('signed encrypted cookie')
        encryptor         = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
        data              = encryptor.decrypt_and_verify(unescaped_content)

        if data['warden.user.user.key'].present?
          data['warden.user.user.key'].first.first
        end
      end
    end

    def lp_user_id_from_session(session)
      session[:lp_user_id]
    end

    def set_lp_user_id(session, cookies)
      session[:lp_user_id] = lp_user_id_from_cookie(cookies)
    end
  end

  attr_reader :controller, :cookies, :session, :logged_in_forum, :logged_in_lp, :lp_user_id

  def initialize(controller)
    @controller      = controller
    @cookies         = controller.send :cookies
    @session         = controller.session
    @logged_in_forum = !!controller.current_user
    @lp_user_id      = self.class.lp_user_id_from_cookie(cookies)
    @logged_in_lp    = !!lp_user_id
  end

  def sync
    if logged_in_forum && !logged_in_lp
      controller.log_off_user
      controller.redirect_to controller.request.path
    elsif (logged_in_forum && logged_in_as_different_user?) || (!logged_in_forum && logged_in_lp)
      dance_sso
    end
  end

  private

  def dance_sso
    controller.redirect_to(controller.session_sso_path(:return_path => controller.request.path))
  end

  def logged_in_as_different_user?
    self.class.lp_user_id_from_session(session) != lp_user_id
  end
end

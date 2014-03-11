class LpSession
  attr_reader :controller, :cookies, :session, :logged_in_forum, :logged_in_lessonplanet

  SESSION_COOKIE_NAME = ENV['MAIN_SITE_COOKIE_NAME']
  NOONCE_COOKIE_NAME  = "#{SESSION_COOKIE_NAME}_noonce"

  def initialize(controller)
    @controller      = controller
    @cookies         = controller.send :cookies
    @session         = controller.session
    @logged_in_forum = !!controller.current_user

    @logged_in_lessonplanet = logged_in_lessonplanet?(cookies[SESSION_COOKIE_NAME])
  end

  def sync
    if logged_in_forum && !logged_in_lessonplanet
      controller.log_off_user
      controller.redirect_to controller.request.path
    elsif logged_in_as_different_user? || (!logged_in_forum && logged_in_lessonplanet)
      dance_sso
    end
  end

  private

  def logged_in_lessonplanet?(content)
    logged_in = false

    if content.present?
      # need to decrypt and verify session cookie
      # to check if use is logged in on lessonplanet.com ain site.
      unescaped_content = URI.unescape(content)
      secret_key_base   = ENV['SECRET_KEY_BASE']
      key_generator     = ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000)
      key_generator     = ActiveSupport::CachingKeyGenerator.new(key_generator)
      secret            = key_generator.generate_key('encrypted cookie')
      sign_secret       = key_generator.generate_key('signed encrypted cookie')
      encryptor         = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
      data              = encryptor.decrypt_and_verify(unescaped_content)

      # if logged in there will be a 'warden.user.user.key' key.
      logged_in = data['warden.user.user.key'].present?
    end

    logged_in
  end

  def dance_sso
    controller.redirect_to(controller.session_sso_path(:return_path => controller.request.path))
  end

  def logged_in_as_different_user?
    different_cookies = cookies[NOONCE_COOKIE_NAME].present? && (cookies[NOONCE_COOKIE_NAME] != cookies[:forums_session_nonce])
    logged_in_forum && logged_in_lessonplanet && different_cookies
  end
end

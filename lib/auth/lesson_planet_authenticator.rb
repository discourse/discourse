module Auth
  class LessonPlanetAuthenticator < ::Auth::Authenticator

    CLIENT_ID = ENV['LESSON_PLANET_CLIENT_ID']
    CLIENT_SECRET = ENV['LESSON_PLANET_SECRET']

    def name
      'lessonplanet'
    end

    def after_authenticate(auth_token)
      # no-op, handled by lp_session_controller and lp_session
    end

    def after_create_account(user, auth)
      # no-op, handled by lp_session_controller and lp_session
    end

    def register_middleware(omniauth)
      omniauth.provider :lessonplanet,
                        CLIENT_ID,
                        CLIENT_SECRET
    end
  end
end

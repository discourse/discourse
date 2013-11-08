require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class LessonPlanet < OmniAuth::Strategies::OAuth2
      AUTH_URL = ENV['LESSON_PLANET_AUTH_URL'] || 'https://www.lessonplanet.com'

      option :name, 'lessonplanet'

      option :client_options, {
          :site => AUTH_URL,
          :authorize_url => "#{AUTH_URL}/oauth/authorize",
          :token_url => "#{AUTH_URL}/oauth/token"
      }

      uid { raw_info['id'] }

      info do
        {
          name: raw_info['name'],
          email: raw_info['email']
        }
      end

      extra do
        { 'raw_info' => raw_info }
      end

      def raw_info
        @raw_info ||= access_token.get('/api/v2/account.json').parsed
      end
    end

  end
end

OmniAuth.config.add_camelization 'lessonplanet', 'LessonPlanet'

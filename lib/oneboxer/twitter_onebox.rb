require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class TwitterOnebox < HandlebarsOnebox
    BASE_URL = 'https://api.twitter.com'.freeze

    REGEX =
      /^https?:\/\/(?:www\.)?twitter.com\/(?<user>[^\/]+)\/status\/(?<id>\d+)$/

    matcher REGEX

    # TODO: use zocial instead
    favicon 'twitter.png'

    def fetch_html
      raise Discourse::SiteSettingMissing if twitter_credentials_missing?

      tweet_for @url.match(REGEX)[:id]
    end

    def parse(data)
      result = JSON.parse(data)

      result['created_at'] =
        Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")

      URI.extract(result['text'], %w(http https)).each do |url|
        result['text'].gsub!(url, "<a href='#{url}' target='_blank'>#{url}</a>")
      end

      result
    end

    private

    def tweet_for(id)
      request = Net::HTTP::Get.new(tweet_uri_for id)

      request.add_field 'Authorization', "Bearer #{bearer_token}"

      http(tweet_uri_for id).request(request).body
    end

    def authorization
      request = Net::HTTP::Post.new(auth_uri)

      request.add_field 'Authorization',
        "Basic #{bearer_token_credentials}"
      request.add_field 'Content-Type',
        'application/x-www-form-urlencoded;charset=UTF-8'

      request.set_form_data 'grant_type' => 'client_credentials'

      http(auth_uri).request(request).body
    end

    def bearer_token
      @access_token ||= JSON.parse(authorization).fetch('access_token')
    end

    def bearer_token_credentials
      Base64.strict_encode64(
        "#{URI::encode(consumer_key)}:#{URI::encode(consumer_secret)}"
      )
    end

    def auth_uri
      URI.parse "#{BASE_URL}/oauth2/token"
    end

    def tweet_uri_for(id)
      URI.parse "#{BASE_URL}/1.1/statuses/show.json?id=#{id}"
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap { |http| http.use_ssl = true }
    end

    def consumer_key
      SiteSetting.twitter_consumer_key
    end

    def consumer_secret
      SiteSetting.twitter_consumer_secret
    end

    def twitter_credentials_missing?
      consumer_key.blank? || consumer_secret.blank?
    end
  end
end

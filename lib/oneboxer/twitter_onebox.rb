require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class TwitterOnebox < HandlebarsOnebox

    unless defined? BASE_URL
      BASE_URL = 'https://api.twitter.com'.freeze
    end

    unless defined? REGEX
      REGEX = /^https?:\/\/(?:www\.)?twitter.com\/(?<user>[^\/]+)\/status\/(?<id>\d+)$/
    end

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

      result['text'] = link_all_the_things_in result['text']

      result
    end

    private

    def link_all_the_things_in(text)
      link_hashtags_in link_handles_in link_urls_in(text)
    end

    def link_urls_in(text)
      URI.extract(text, %w(http https)).each do |url|
        text.gsub!(url, "<a href='#{url}' target='_blank'>#{url}</a>")
      end

      text
    end

    def link_handles_in(text)
      text.scan(/\s@(\w+)/).flatten.uniq.each do |handle|
        text.gsub!("@#{handle}", [
          "<a href='https://twitter.com/#{handle}' target='_blank'>",
            "@#{handle}",
          "</a>"
        ].join)
      end

      text
    end

    def link_hashtags_in(text)
      text.scan(/\s#(\w+)/).flatten.uniq.each do |hashtag|
        text.gsub!("##{hashtag}", [
          "<a href='https://twitter.com/search?q=%23#{hashtag}' ",
          "target='_blank'>",
            "##{hashtag}",
          "</a>"
        ].join)
      end

      text
    end

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

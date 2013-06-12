# TODO implement per: http://meta.discourse.org/t/twitter-oneboxes-are-bust/7410/3
require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class TwitterOnebox < HandlebarsOnebox

    REGEX = /^https?:\/\/(?:www\.)?twitter.com\/(?<user>[^\/]+)\/status\/(?<id>\d+)$/
    # matcher REGEX

    # TODO: use zocial instead
    favicon 'twitter.png'

    def fetch_html
      m = @url.match(REGEX)

      if SiteSetting.twitter_consumer_key.present? && SiteSetting.twitter_consumer_secret.present?
        token = prepare_access_token(SiteSetting.twitter_consumer_key, SiteSetting.twitter_consumer_secret)
        token.request(:get, "https://api.twitter.com/1.1/statuses/show/#{URI::encode(m[:id])}.json")
      else
        # perhaps?
        raise Discourse::SiteSettingMissing
      end
    end

    def parse(data)
      result = JSON.parse(data)

      result["created_at"] = Time.parse(result["created_at"]).strftime("%I:%M%p - %d %b %y")

      # Hyperlink URLs
      URI.extract(result['text'], %w(http https)).each do |url|
        result['text'].gsub!(url, "<a href='#{url}' target='_blank'>#{url}</a>")
      end

      result
    end

    protected

    def get_message_json(consumer_key, consumer_secret)
      raise "NOT IMPLEMENTED"
      # implement per http://meta.discourse.org/t/twitter-oneboxes-are-bust/7410/3
    end


  end
end

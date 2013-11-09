require_dependency 'oneboxer/handlebars_onebox'
require_dependency 'twitter_api'

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
      raise Discourse::SiteSettingMissing if TwitterApi.twitter_credentials_missing?

      # a bit odd, but I think the api expects html
      TwitterApi.raw_tweet_for(@url.match(REGEX)[:id])
    end

    def parse(data)
      result = JSON.parse(data)

      result['created_at'] =
        Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")

      result['text'] = TwitterApi.prettify_tweet(result)

      result
    end

  end
end

require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class TwitterOnebox < HandlebarsOnebox

    matcher /^https?:\/\/(?:www\.)?twitter.com\/.*$/
    favicon 'twitter.png'

    def translate_url
      m = @url.match(/\/(?<user>[^\/]+)\/status\/(?<id>\d+)/mi)
      return "http://api.twitter.com/1/statuses/show/#{URI::encode(m[:id])}.json" if m.present?
      @url
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

  end
end

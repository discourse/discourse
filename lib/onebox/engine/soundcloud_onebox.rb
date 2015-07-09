module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*soundcloud\.com/)
      always_https

      def to_html
        get_oembed_data[:html].gsub!('height="400"', 'height="250"')
      end

      def placeholder_html
        "<img src='#{get_oembed_data[:thumbnail_url]}'>"
      end

      private

      def get_oembed_data
        Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response("https://soundcloud.com/oembed.json?url=#{url}").body))
      end
    end
  end
end

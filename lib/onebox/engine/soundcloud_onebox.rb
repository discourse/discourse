module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*soundcloud\.com/)
      always_https

      def to_html
        oembed_data = get_oembed_data[:html]
        oembed_data.gsub!('visual=true', 'visual=false') || oembed_data
      end

      def placeholder_html
        "<img src='#{get_oembed_data[:thumbnail_url]}'>"
      end

      private

      def set?
        url =~ /\/sets\//
      end

      def get_oembed_data
        if set?
          Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response("https://soundcloud.com/oembed.json?url=#{url}").body))
        else
          Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response("https://soundcloud.com/oembed.json?url=#{url}&maxheight=166").body))
        end
      end
    end
  end
end

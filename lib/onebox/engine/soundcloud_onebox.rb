module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/soundcloud\.com/)
      always_https

      def to_html
        oembed_data[:html].gsub('visual=true', 'visual=false')
      end

      def placeholder_html
        return if Onebox::Helpers.blank?(oembed_data[:thumbnail_url])
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(oembed_data[:thumbnail_url])
        "<img src='#{escaped_src}' #{Helpers.title_attr(oembed_data)}>"
      end

      private

        def oembed_data
          @oembed_data ||= begin
            oembed_url = "https://soundcloud.com/oembed.json?url=#{url}"
            oembed_url << "&maxheight=166" unless url["/sets/"]
            response = Onebox::Helpers.fetch_response(oembed_url) rescue "{}"
            Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
          rescue
            {}
          end
        end

    end
  end
end

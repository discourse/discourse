module Onebox
  module Engine
    class WistiaOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/https?:\/\/(.+)?(wistia.com|wi.st)\/(medias|embed)\/.*/)
      always_https

      def to_html
        oembed_data[:html]
      end

      def placeholder_html
        return if Onebox::Helpers.blank?(oembed_data[:thumbnail_url])
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(oembed_data[:thumbnail_url])
        "<img src='#{escaped_src}' #{Helpers.title_attr(oembed_data)}>"
      end

      private
      def oembed_data
        @oembed_data ||= begin
          oembed_url = "https://fast.wistia.com/oembed?embedType=iframe&url=#{url}"
          response = Onebox::Helpers.fetch_response(oembed_url) rescue "{}"
          Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
        rescue
          {}
        end
      end
    end
  end
end

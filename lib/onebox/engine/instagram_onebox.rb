# frozen_string_literal: true

module Onebox
  module Engine
    class InstagramOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/?(?:.*)\/p\/[a-zA-Z\d_-]+/)
      always_https

      def clean_url
        url.scan(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/?(?:.*)\/p\/[a-zA-Z\d_-]+/).flatten.first
      end

      def data
        oembed = get_oembed
        permalink = clean_url.gsub("/#{oembed.author_name}/", "/")

        { link: permalink,
          title: "@#{oembed.author_name}",
          image: "#{permalink}/media/?size=l",
          description: Onebox::Helpers.truncate(oembed.title, 250)
        }
      end

      protected

      def get_oembed_url
        oembed_url = "https://api.instagram.com/oembed/?url=#{clean_url}"
      end
    end
  end
end

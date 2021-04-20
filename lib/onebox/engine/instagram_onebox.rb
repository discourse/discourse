# frozen_string_literal: true

module Onebox
  module Engine
    class InstagramOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/?(?:.*)\/(?:p|tv)\/[a-zA-Z\d_-]+/)
      always_https

      def clean_url
        url.scan(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/?(?:.*)\/(?:p|tv)\/[a-zA-Z\d_-]+/).flatten.first
      end

      def data
        oembed = get_oembed
        raise "No oEmbed data found. Ensure 'facebook_app_access_token' is valid" if oembed.data.empty?

        {
          link: clean_url.gsub("/#{oembed.author_name}/", "/"),
          title: "@#{oembed.author_name}",
          image: oembed.thumbnail_url,
          description: Onebox::Helpers.truncate(oembed.title, 250),
        }

      end

      protected

      def access_token
        (options[:facebook_app_access_token] || Onebox.options.facebook_app_access_token).to_s
      end

      def get_oembed_url
        if access_token != ''
          "https://graph.facebook.com/v9.0/instagram_oembed?url=#{clean_url}&access_token=#{access_token}"
        else
          # The following is officially deprecated by Instagram, but works in some limited circumstances.
          "https://api.instagram.com/oembed/?url=#{clean_url}"
        end
      end
    end
  end
end

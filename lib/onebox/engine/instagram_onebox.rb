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
        og = get_opengraph

        # There are at least two different versions of the description. e.g.
        # - "3,227 Likes, 88 Comments - An Account (@user.name) on Instagram: “Look at my picture!”"
        # - "@user.name posted on their Instagram profile: “Look at my picture!”"

        m = og.description.match(/\(@([\w\.]+)\) on Instagram/)
        author_name = m[1] if m

        author_name ||= begin
          m = og.description.match(/^\@([\w\.]+)\ posted/)
          m[1] if m
        end

        raise "Author username not found for post #{clean_url}" unless author_name

        permalink = clean_url.gsub("/#{author_name}/", "/")

        { link: permalink,
          title: "@#{author_name}",
          image: og.image,
          description: Onebox::Helpers.truncate(og.title, 250)
        }
      end

      protected

      def get_oembed_url
        oembed_url = "https://api.instagram.com/oembed/?url=#{clean_url}"
      end
    end
  end
end

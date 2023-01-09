# frozen_string_literal: true

module Onebox
  module Engine
    class InstagramOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(
        %r{^https?://(?:www\.)?(?:instagram\.com|instagr\.am)/?(?:.*)/(?:p|tv)/[a-zA-Z\d_-]+},
      )
      always_https
      requires_iframe_origins "https://www.instagram.com"

      def clean_url
        url
          .scan(
            %r{^https?://(?:www\.)?(?:instagram\.com|instagr\.am)/?(?:.*)/(?:p|tv)/[a-zA-Z\d_-]+},
          )
          .flatten
          .first
      end

      def data
        @data ||=
          begin
            oembed = get_oembed
            if oembed.data.empty?
              raise "No oEmbed data found. Ensure 'facebook_app_access_token' is valid"
            end

            {
              link: clean_url.gsub("/#{oembed.author_name}/", "/") + "/embed",
              title: "@#{oembed.author_name}",
              image: oembed.thumbnail_url,
              image_width: oembed.data[:thumbnail_width],
              image_height: oembed.data[:thumbnail_height],
              description: Onebox::Helpers.truncate(oembed.title, 250),
            }
          end
      end

      def placeholder_html
        ::Onebox::Helpers.image_placeholder_html
      end

      def to_html
        <<-HTML
          <iframe
            src="#{data[:link]}"
            width="#{data[:image_width]}"
            height="#{data[:image_height].to_i + 98}"
            frameborder="0"
          ></iframe>
        HTML
      end

      protected

      def access_token
        (options[:facebook_app_access_token] || Onebox.options.facebook_app_access_token).to_s
      end

      def get_oembed_url
        if access_token != ""
          "https://graph.facebook.com/v9.0/instagram_oembed?url=#{clean_url}&access_token=#{access_token}"
        else
          # The following is officially deprecated by Instagram, but works in some limited circumstances.
          "https://api.instagram.com/oembed/?url=#{clean_url}"
        end
      end
    end
  end
end

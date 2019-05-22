# frozen_string_literal: true

require 'htmlentities'

module Onebox
  module Engine
    class InstagramOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/?(?:.*)\/p\//)
      always_https

      def data
        og = get_opengraph
        title = og.title.split(":")[0].strip.gsub(" on Instagram", "")

        json_data = html_doc.xpath('//script[contains(text(),"window._sharedData")]').text.to_s
        title = "[Album] #{title}" if json_data =~ /"edge_sidecar_to_children"/

        result = { link: og.url,
                   title: Onebox::Helpers.truncate(title, 80),
                   description: og.description(250)
                  }

        result[:image] = og.image if !og.image.nil?
        result[:video_link] = og.url if !og.video_secure_url.nil?

        result
      end
    end
  end
end

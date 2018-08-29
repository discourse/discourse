require 'htmlentities'

module Onebox
  module Engine
    class InstagramOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^https?:\/\/(?:www\.)?(?:instagram\.com|instagr\.am)\/p\//)
      always_https

      def data
        og = get_opengraph
        title = og[:title].split(":")[0].strip
        html_entities = HTMLEntities.new

        json_data = html_doc.xpath('//script[contains(text(),"window._sharedData")]').text.to_s
        title = "[Album] #{title}" if json_data =~ /"edge_sidecar_to_children"/

        result = { link: og[:url],
                   title: html_entities.decode(Onebox::Helpers.truncate(title, 80)),
                   description: html_entities.decode(Sanitize.fragment(Onebox::Helpers.truncate(og[:description].strip, 250)))
                  }

        if !Onebox::Helpers.blank?(og[:image])
          result[:image] = ::Onebox::Helpers.normalize_url_for_output(og[:image])
        end

        if !Onebox::Helpers.blank?(og[:video_secure_url])
          result[:video_link] = og[:url]
        end

        result
      end
    end
  end
end

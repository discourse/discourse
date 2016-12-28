module Onebox
  module Engine
    class ReplitOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/repl\.it\/.+/)
      always_https

      def placeholder_html
        oembed = get_oembed

        # we want the image to have the same dimensions as the embedded html

        <<-HTML
          <img src="#{oembed[:thumbnail_url]}" style="max-width: #{oembed[:width]}px; max-height: #{oembed[:height]}px;" #{Helpers.title_attr(oembed)}>
        HTML
      end

      def to_html
        oembed = get_oembed
        oembed[:html]
      end

    end
  end
end

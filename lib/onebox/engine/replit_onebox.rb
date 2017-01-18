module Onebox
  module Engine
    class ReplitOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/repl\.it\/.+/)
      always_https

      def placeholder_html
        oembed = get_oembed
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(oembed[:thumbnail_url])

        <<-HTML
          <img src="#{escaped_src}" style="max-width: #{oembed[:width]}px; max-height: #{oembed[:height]}px;" #{Helpers.title_attr(oembed)}>
        HTML
      end

      def to_html
        oembed = get_oembed
        oembed[:html]
      end

    end
  end
end

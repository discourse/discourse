module Onebox
  module Engine
    class TypeformOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/[a-z0-9]+\.typeform\.com\/to\/[a-zA-Z0-9]+/)
      always_https

      def placeholder_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:image])
        "<img src='#{escaped_src}' #{Helpers.title_attr(og)}>"
      end

      def to_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:url])

        <<-HTML
          <iframe src="#{escaped_src}"
                  width="100%"
                  height="600px"
                  scrolling="no"
                  frameborder="0">
          </iframe>
        HTML
      end
    end
  end
end

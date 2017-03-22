module Onebox
  module Engine
    class TypeformOnebox
      include Engine

      matches_regexp(/^https?:\/\/[a-z0-9]+\.typeform\.com\/to\/[a-zA-Z0-9]+/)
      always_https

      def placeholder_html
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)

        <<-HTML
          <iframe src="#{escaped_url}"
                  width="100%"
                  height="600px"
                  scrolling="no"
                  frameborder="0">
          </iframe>
        HTML
      end

      def to_html
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)
        <<-HTML
          <iframe src="#{escaped_url}"
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

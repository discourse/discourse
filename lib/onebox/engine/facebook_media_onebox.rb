# frozen_string_literal: true

module Onebox
  module Engine
    class FacebookMediaOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://.*\.facebook\.com/(\w+)/(videos|\?).*})
      always_https
      requires_iframe_origins "https://www.facebook.com"

      def to_html
        metadata = get_twitter
        if metadata.present? && metadata[:card] == "player" && metadata[:player].present?
          <<-HTML
            <iframe
              src="#{metadata[:player]}"
              width="#{metadata[:player_width]}"
              height="#{metadata[:player_height]}"
              scrolling="no"
              frameborder="0"
              allowfullscreen
            ></iframe>
          HTML
        else
          html = Onebox::Engine::AllowlistedGenericOnebox.new(@url, @timeout).to_html
          return if Onebox::Helpers.blank?(html)
          html
        end
      end
    end
  end
end

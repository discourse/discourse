# frozen_string_literal: true

module Onebox
  module Engine
    class SteamStoreOnebox
      include Engine
      include StandardEmbed

      matches_domain("store.steampowered.com")
      always_https
      requires_iframe_origins "https://store.steampowered.com"

      def self.matches_path(path)
        path.match?(%r{^/app/\d+$})
      end

      def placeholder_html
        og = get_opengraph
        <<-HTML
          <div style='width:100%; height:190px; background-color:#262626; color:#9e9e9e; margin:15px 0;'>
            <div style='padding:10px'>
              <h3 style='color:#fff; margin:10px 0 10px 5px;'>#{og.title}</h3>
              <img src='#{og.image}' style='float:left; max-width:184px; margin:5px 15px 0 5px'/>
              <p>#{og.description}</p>
            </div>
          </div>
        HTML
      end

      def to_html
        iframe_url = @url[%r{https?://store\.steampowered\.com/app/\d+}].gsub("/app/", "/widget/")
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(iframe_url)

        <<-HTML
          <iframe
            src='#{escaped_src}'
            frameborder='0'
            width='100%'
            height='190'
          ></iframe>
        HTML
      end
    end
  end
end

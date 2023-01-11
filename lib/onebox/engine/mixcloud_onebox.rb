# frozen_string_literal: true

module Onebox
  module Engine
    class MixcloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://www\.mixcloud\.com/})
      always_https
      requires_iframe_origins "https://www.mixcloud.com"

      def placeholder_html
        oembed = get_oembed

        <<-HTML
          <aside class="onebox mixcloud-preview">
            <article class="onebox-body">
              <img src="#{oembed.image}">
              <div class="video-icon"></div>
              <div class="mixcloud-text">
                <h3><a href="#{oembed.url}" target="_blank" rel="nofollow ugc noopener">#{oembed.title}</a></h3>
                <h4>#{oembed.author_name}</h4>
              </div>
            </article>
          </aside>
        HTML
      end

      def to_html
        get_oembed.html
      end
    end
  end
end

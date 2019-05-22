# frozen_string_literal: true

module Onebox
  module Engine
    class RedditImageOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?reddit\.com/)

      def to_html
        if raw[:type] == "image"
          <<-HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="#{raw[:favicon]}" class="site-icon" width="16" height="16">
                <a href="#{raw[:url]}" target="_blank" rel="nofollow noopener">#{raw[:site_name]}</a>
              </header>
              <article class="onebox-body">
                <h3><a href="#{raw[:url]}" target="_blank" rel="nofollow noopener">#{raw[:title]}</a></h3>
                <div class="scale-images">
                  <img src="#{raw[:image]}" class="scale-image"/>
                </div>
                <div class="description"><p>#{raw[:description]}</p></div>
              </article>
            </aside>
          HTML
        else
          html = Onebox::Engine::WhitelistedGenericOnebox.new(@url, @cache, @timeout).to_html
          return if Onebox::Helpers.blank?(html)
          html
        end
      end
    end
  end
end

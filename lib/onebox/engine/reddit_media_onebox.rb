# frozen_string_literal: true

module Onebox
  module Engine
    class RedditMediaOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_domain("reddit.com", "www.reddit.com")

      def to_html
        if raw[:type] == "image"
          <<-HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="#{raw[:favicon]}" class="site-icon" width="16" height="16">
                <a href="#{raw[:url]}" target="_blank" rel="nofollow ugc noopener">#{raw[:site_name]}</a>
              </header>
              <article class="onebox-body">
                <h3><a href="#{raw[:url]}" target="_blank" rel="nofollow ugc noopener">#{raw[:title]}</a></h3>
                <div class="scale-images">
                  <img src="#{raw[:image]}" class="scale-image"/>
                </div>
                <div class="description"><p>#{raw[:description]}</p></div>
              </article>
            </aside>
          HTML
        elsif raw[:type] =~ %r{^video[/\.]}
          <<-HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="#{raw[:favicon]}" class="site-icon" width="16" height="16">
                <a href="#{raw[:url]}" target="_blank" rel="nofollow ugc noopener">#{raw[:site_name]}</a>
              </header>
              <article class="onebox-body">
                <h3><a href="#{raw[:url]}" target="_blank" rel="nofollow ugc noopener">#{raw[:title]}</a></h3>
                <div class="aspect-image-full-size">
                  <a href="#{raw[:url]}" target="_blank" rel="nofollow ugc noopener" class="image-wrapper">
                    <img src="#{raw[:image]}" class="scale-image"/>
                    <span class="video-icon"></span>
                  </a>
                </div>
                <div class="description"><p>#{raw[:description]}</p></div>
              </article>
            </aside>
          HTML
        else
          html = Onebox::Engine::AllowlistedGenericOnebox.new(@url, @timeout).to_html
          html.presence
        end
      end
    end
  end
end

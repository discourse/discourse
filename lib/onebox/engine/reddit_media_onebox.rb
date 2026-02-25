# frozen_string_literal: true

require_relative "../mixins/reddit_auth_header"

module Onebox
  module Engine
    class RedditMediaOnebox
      include Engine
      include Onebox::Mixins::RedditAuthHeader

      always_https
      matches_domain(
        "reddit.com",
        "www.reddit.com",
        "old.reddit.com",
        "np.reddit.com",
        "new.reddit.com",
      )

      def self.matches_path(path)
        path.match?(%r{^/r/[^/]+/comments/[^/]+})
      end

      def to_html
        post = reddit_post
        return nil unless post

        url = Onebox::Helpers.normalize_url_for_output("https://www.reddit.com#{post["permalink"]}")
        subreddit_url =
          Onebox::Helpers.normalize_url_for_output(
            "https://www.reddit.com/#{post["subreddit_name_prefixed"]}",
          )
        title = CGI.escapeHTML(Onebox::Helpers.truncate(post["title"].to_s, 80))
        subreddit = CGI.escapeHTML(post["subreddit_name_prefixed"].to_s)
        author = CGI.escapeHTML(post["author"].to_s)
        score = post["score"].to_i
        num_comments = post["num_comments"].to_i
        nsfw_label = post["over_18"] ? " <span class='nsfw'>NSFW</span>" : ""
        meta = "#{score} points | #{num_comments} comments — u/#{author}"

        if image_post?(post)
          image_url = extract_image_url(post)
          return nil unless image_url

          image_url = Onebox::Helpers.normalize_url_for_output(image_url)

          <<~HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="https://www.reddit.com/favicon.ico" class="site-icon" width="16" height="16">
                <a href="#{subreddit_url}" target="_blank" rel="nofollow ugc noopener">#{subreddit}</a>
              </header>
              <article class="onebox-body">
                <h3><a href="#{url}" target="_blank" rel="nofollow ugc noopener">#{title}#{nsfw_label}</a></h3>
                <div class="scale-images">
                  <img src="#{image_url}" class="scale-image"/>
                </div>
                <div class="description"><p>#{meta}</p></div>
              </article>
            </aside>
          HTML
        elsif video_post?(post)
          preview_url = extract_image_url(post)
          preview_html =
            if preview_url
              preview_url = Onebox::Helpers.normalize_url_for_output(preview_url)
              "<div class=\"reddit-preview-thumbnail\"><img src=\"#{preview_url}\" class=\"thumbnail\"/></div>"
            else
              ""
            end

          <<~HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="https://www.reddit.com/favicon.ico" class="site-icon" width="16" height="16">
                <a href="#{subreddit_url}" target="_blank" rel="nofollow ugc noopener">#{subreddit}</a>
              </header>
              <article class="onebox-body reddit-preview-onebox">
                #{preview_html}
                <div class="reddit-preview-details">
                  <h3><a href="#{url}" target="_blank" rel="nofollow ugc noopener">#{title}#{nsfw_label}</a></h3>
                  <div class="description"><p>#{meta}</p></div>
                </div>
              </article>
            </aside>
          HTML
        else
          description_html =
            if post["is_self"] && post["selftext"].present?
              desc = CGI.escapeHTML(Onebox::Helpers.truncate(post["selftext"], 250))
              "<div class=\"description\"><p>#{desc}</p></div>"
            else
              ""
            end

          <<~HTML
            <aside class="onebox reddit">
              <header class="source">
                <img src="https://www.reddit.com/favicon.ico" class="site-icon" width="16" height="16">
                <a href="#{subreddit_url}" target="_blank" rel="nofollow ugc noopener">#{subreddit}</a>
              </header>
              <article class="onebox-body">
                <h3><a href="#{url}" target="_blank" rel="nofollow ugc noopener">#{title}#{nsfw_label}</a></h3>
                #{description_html}
                <div class="description"><p>#{meta}</p></div>
              </article>
            </aside>
          HTML
        end
      end

      private

      def reddit_post
        return @reddit_post if defined?(@reddit_post)

        json_url = @url.sub(%r{/?(\?.*)?$}, ".json")
        headers = reddit_auth_header
        if headers.any?
          json_url =
            json_url
              .sub("://www.reddit.com", "://oauth.reddit.com")
              .sub("://old.reddit.com", "://oauth.reddit.com")
              .sub("://np.reddit.com", "://oauth.reddit.com")
              .sub("://new.reddit.com", "://oauth.reddit.com")
        end
        response = Onebox::Helpers.fetch_response(json_url, headers:)
        parsed = ::MultiJson.load(response)
        @reddit_post = parsed[0]["data"]["children"][0]["data"]
      rescue StandardError
        @reddit_post = nil
      end

      def image_post?(post)
        post["post_hint"] == "image" ||
          post["url"].to_s.match?(/\.(jpg|jpeg|png|gif|webp)(\?.*)?$/i)
      end

      def video_post?(post)
        post["is_video"] || post["post_hint"].to_s.include?("video")
      end

      def extract_image_url(post)
        if post["url"].to_s.match?(/\.(jpg|jpeg|png|gif|webp)(\?.*)?$/i)
          return CGI.unescapeHTML(post["url"])
        end

        preview_url = post.dig("preview", "images", 0, "source", "url")
        CGI.unescapeHTML(preview_url) if preview_url
      end
    end
  end
end

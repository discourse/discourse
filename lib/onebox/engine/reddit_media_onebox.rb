# frozen_string_literal: true

module Onebox
  module Engine
    class RedditMediaOnebox
      include Engine

      always_https
      requires_iframe_origins "https://embed.reddit.com", "https://sh.reddit.com"
      matches_domain(
        "reddit.com",
        "www.reddit.com",
        "old.reddit.com",
        "np.reddit.com",
        "new.reddit.com",
      )

      def self.matches_path(path)
        path.match?(%r{^/(?:r|user)/[^/]+/comments/[^/]+})
      end

      def to_html
        <<~HTML
          <iframe
            class="reddit-onebox"
            src="#{embed_url}"
            width="640"
            height="#{default_height}"
            allowfullscreen
          ></iframe>
        HTML
      end

      def placeholder_html
        Onebox::Helpers.generic_placeholder_html
      end

      private

      def embed_url
        @embed_url ||=
          Onebox::Helpers.normalize_url_for_output(
            URI::HTTPS.build(
              host: "embed.reddit.com",
              path: normalized_path,
              query: URI.encode_www_form(embed_params),
            ).to_s,
          )
      end

      def normalized_path
        return "#{uri.path}/" unless uri.path.end_with?("/")
        uri.path
      end

      def embed_params
        params = { embed: true, ref_source: "embed", ref: "share" }

        if comment_path?
          params[:showmedia] = false
          params[:showmore] = false
          params[:depth] = 1
          params[:context] = 1
        end

        params
      end

      def comment_path?
        uri.path.match?(%r{^/(?:r|user)/[^/]+/comments/[^/]+/[^/]*/[^/]+/?$})
      end

      def default_height
        comment_path? ? 300 : 500
      end
    end
  end
end

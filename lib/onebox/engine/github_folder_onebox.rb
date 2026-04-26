# frozen_string_literal: true

module Onebox
  module Engine
    class GithubFolderOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_domain("github.com", "www.github.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/[\w\-]+/[\w\-]+/tree/})
      end

      private

      def data
        og = get_opengraph

        max_length = 250

        display_path, fallback_title = extract_path(max_length)
        display_description = clean_description(og.description, og.title, max_length)

        title = og.title || fallback_title

        fragment = Addressable::URI.parse(url).fragment
        if fragment
          fragment = Addressable::URI.unencode(fragment)

          # For links to markdown and rdoc
          if html_doc.css(".Box.md, .Box.rdoc").present?
            node = html_doc.css("a.anchor").find { |n| n["href"] == "##{fragment}" }
            subtitle = node&.parent&.text
          end

          title = "#{title} - #{subtitle}" if subtitle
        end

        {
          link: url,
          title: Onebox::Helpers.truncate(title, 250),
          path: display_path,
          description: display_description,
          favicon: get_favicon,
        }
      end

      def extract_path(max_length)
        clean_url = url.split("#")[0].split("?")[0]
        match = clean_url.match(%r{github\.com/([\w\-]+/[\w\-]+)/tree/(.+)})

        return unless match

        title, path = match.captures
        [path.length > max_length ? path[-max_length..] : path, title]
      end

      def clean_description(description, title, max_length)
        return unless description

        desc_end = " - #{title}"
        if description[-desc_end.length..-1] == desc_end
          description = description[0...-desc_end.length]
        end

        Onebox::Helpers.truncate(description, max_length)
      end
    end
  end
end

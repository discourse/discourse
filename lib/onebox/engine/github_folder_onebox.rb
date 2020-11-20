# frozen_string_literal: true

module Onebox
  module Engine
    class GithubFolderOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp Regexp.new(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?(github)\.com[\:\d]*(\/\w*){2}\/tree/)
      always_https

      private

      def data
        og = get_opengraph

        max_length = 250

        display_path = extract_path(og.url, max_length)
        display_description = clean_description(og.description, og.title, max_length)

        {
          link: og.url,
          path_link: url,
          image: og.image,
          title: og.title,
          path: display_path,
          description: display_description,
          favicon: get_favicon
        }
      end

      def extract_path(root, max_length)
        path = url.split('#')[0].split('?')[0]
        path = path["#{root}/tree/".length..-1]
        path.length > max_length ? path[-max_length..-1] : path
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

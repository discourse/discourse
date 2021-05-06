# frozen_string_literal: true

module Onebox
  module Engine
    class WikimediaOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp(/^https?:\/\/commons\.wikimedia\.org\/wiki\/(File:.+)/)
      always_https

      def self.priority
        # Wikimedia links end in an image extension.
        # E.g. https://commons.wikimedia.org/wiki/File:Stones_members_montage2.jpg
        # This engine should have priority over the generic ImageOnebox.

        1
      end

      def url
        "https://en.wikipedia.org/w/api.php?action=query&titles=#{match[:name]}&prop=imageinfo&iilimit=50&iiprop=timestamp|user|url&iiurlwidth=500&format=json"
      end

      private

      def match
        @match ||= @url.match(/^https?:\/\/commons\.wikimedia\.org\/wiki\/(?<name>File:.+)/)
      end

      def data
        first_page = raw['query']['pages'].first[1]

        {
          link: first_page['imageinfo'].first['descriptionurl'],
          title: first_page['title'],
          image: first_page['imageinfo'].first['url'],
          thumbnail: first_page['imageinfo'].first['thumburl']
        }
      end
    end
  end
end

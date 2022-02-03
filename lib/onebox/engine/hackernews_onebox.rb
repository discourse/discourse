# frozen_string_literal: true

module Onebox
  module Engine
    class HackernewsOnebox
      include Engine
      include LayoutSupport
      include JSON

      REGEX = /^https?:\/\/news\.ycombinator\.com\/item\?id=(?<item_id>\d+)/

      matches_regexp(REGEX)

      # This is their official API: https://blog.ycombinator.com/hacker-news-api/
      def url
        "https://hacker-news.firebaseio.com/v0/item/#{match[:item_id]}.json"
      end

      private

      def match
        @match ||= @url.match(REGEX)
      end

      def data
        return nil unless %w{story comment}.include?(raw['type'])

        html_entities = HTMLEntities.new
        data = {
          link: @url,
          title: Onebox::Helpers.truncate(raw['title'], 80),
          favicon: 'https://news.ycombinator.com/y18.gif',
          timestamp: Time.at(raw['time']).strftime("%-l:%M %p - %-d %b %Y"),
          author: raw['by']
        }

        data['description'] = html_entities.decode(Onebox::Helpers.truncate(raw['text'], 400)) if raw['text']

        if raw['type'] == 'story'
          data['data_1'] = raw['score']
          data['data_2'] = raw['descendants']
        end

        data
      end
    end
  end
end

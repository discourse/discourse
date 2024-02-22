# frozen_string_literal: true

module Onebox
  module Engine
    class ThreadsStatusOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp(%r{^https?://www\.threads\.net/t/(?<id>[\d\w_-]+)/?.*?$})
      always_https

      def self.priority
        1
      end

      private

      def link
        raw.css("link[rel='canonical']").first["href"]
      end

      def likes
        @og[:description].split(" ").first
      end

      def replies
        @og[:description].split(", ").drop(1).join(", ").split(" repl").first
      end

      def description
        text = @og[:description].split(". ").drop(1).join(". ")
        linkify_mentions(text)
      end

      def title
        @og[:title].split(" (@").first
      end

      def screen_name
        @og[:title].split(" (@").drop(1).join(" (@").split(") on Threads")[0]
      end

      def avatar
        poster_response =
          begin
            Onebox::Helpers.fetch_response("https://www.threads.net/@#{screen_name}")
          rescue StandardError
            return nil
          end
        poster_html = Nokogiri.HTML(poster_response)
        poster_data = ::Onebox::OpenGraph.new(poster_html).data
        poster_data[:image]
      end

      def image
        @og[:image]
      end

      def favicon
        raw.css("link[rel='icon']").first["href"]
      end

      def linkify_mentions(text)
        text.gsub(/@([\w\d]+)/, "<a href='https://www.threads.net/@\\1'>@\\1</a>")
      end

      def data
        @og = ::Onebox::OpenGraph.new(raw).data

        @data ||= {
          favicon: favicon,
          link: link,
          description: description,
          image: image,
          title: title,
          screen_name: screen_name,
          avatar: avatar,
          likes: likes,
          replies: replies,
        }

        # if the image is the same as the avatar, don't show it
        # means it's a thread with no image
        @data[:image] = nil if @data[:image].split("?").first == @data[:avatar].split("?").first

        @data
      end
    end
  end
end

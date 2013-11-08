module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include HTML

      matches do
        http
        maybe("www.")
        domain("twitter")
        tld("com")
        anything
        has("/status/")
      end

      private

      def match
        @match ||= @url.match(/twitter\.com\/.+?\/status\/(?<id>\d+)/)
      end

      def client
        Onebox.options.twitter_client
      end

      def raw
        if client
          @raw ||= OpenStruct.new(client.status(match[:id]).to_hash)
        else
          super
        end
      end

      def tweet
        if raw.html?
          raw.css(".tweet-text").inner_text
        else
          raw.text
        end
      end

      def timestamp
        if raw.html?
          raw.css(".metadata span").inner_text
        else
          raw.created_at
        end
      end

      def title
        if raw.html?
          raw.css(".stream-item-header .username").inner_text
        else
          raw.user[:screen_name]
        end
      end

      def avatar
        if raw.html?
          raw.css(".avatar")[2]["src"]
        else
          raw.user[:profile_image_url]
        end
      end

      def favorites
        if raw.html?
          raw.css(".stats li .request-favorited-popup").inner_text
        else
          raw.favorite_count
        end
      end

      def retweets
        if raw.html?
          raw.css(".stats li .request-retweeted-popup").inner_text
        else
          raw.retweet_count
        end
      end

      def data
        {
          link: link,
          domain: "http://www.twitter.com",
          badge: "t",
          tweet: tweet,
          timestamp: timestamp,
          title: title,
          avatar: avatar,
          favorites: favorites,
          retweets: retweets
        }
      end
    end
  end
end

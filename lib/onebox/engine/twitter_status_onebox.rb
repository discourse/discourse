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

      def client
        Onebox.options.twitter_client
      end

      def raw
        if client
          @raw ||= client.status(id)
        else
          super
        end
      end

      def data
        {
          link: link,
          domain: "http://www.twitter.com",
          badge: "t",
          tweet: raw.css(".tweet-text").inner_text,
          timestamp: raw.css(".metadata span").inner_text,
          title: raw.css(".stream-item-header .username").inner_text,
          avatar: raw.css(".avatar")[2]["src"],
          favorites: raw.css(".stats li .request-favorited-popup").inner_text,
          retweets: raw.css(".stats li .request-retweeted-popup").inner_text
        }
      end
    end
  end
end

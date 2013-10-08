module Onebox
  module Engine
    class TwitterOnebox
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

      def data
        {
          url: @url,
          tweet_text: raw.css(".tweet-text").inner_text,
          time_date: raw.css(".metadata span").inner_text,
          user: raw.css(".stream-item-header .username").inner_text,
          avatar: raw.css(".avatar")[2]["src"],
          favorites: raw.css(".stats li .request-favorited-popup").inner_text,
          retweets: raw.css(".stats li .request-retweeted-popup").inner_text
        }
      end
    end
  end
end

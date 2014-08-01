module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp Regexp.new("^http(?:s)?://(?:www\\.)?(?:(?:\\w)+\\.)?(twitter)\\.com(?:/)?(?:.)*/status(es)?/")

      private

      def match
        @match ||= @url.match(%r{twitter\.com/.+?/status(es)?/(?<id>\d+)})
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

      def access(*keys)
        keys.reduce(raw) do |memo, key|
          memo[key] || memo[key.to_s]
        end
      end

      def tweet
        if raw.html?
          raw.css(".tweet-text")[0].inner_text
        else
          access(:text)
        end
      end

      def timestamp
        if raw.html?
          raw.css(".metadata span")[0].inner_text
        else
          created_at = access(:created_at)
          date = DateTime.strptime(created_at, "%a %b %d %H:%M:%S %z %Y")
          user_offset = access(:user, :utc_offset).to_i
          offset = (user_offset >= 0 ? "+" : "-") + Time.at(user_offset.abs).gmtime.strftime("%H%M")
          date.new_offset(offset).strftime("%l:%M %p - %e %b %Y")
        end
      end

      def title
        if raw.html?
          raw.css(".stream-item-header .username").inner_text
        else
          access(:user, :screen_name)
        end
      end

      def avatar
        if raw.html?
          raw.css(".avatar")[2]["src"]
        else
          access(:user, :profile_image_url)
        end
      end

      def favorites
        if raw.html?
          raw.css(".stats li .request-favorited-popup").inner_text
        else
          access(:favorite_count)
        end
      end

      def retweets
        if raw.html?
          raw.css(".stats li .request-retweeted-popup").inner_text
        else
          access(:retweet_count)
        end
      end

      def data
        { link: link,
          tweet: tweet,
          timestamp: timestamp,
          title: title,
          avatar: avatar,
          favorites: favorites,
          retweets: retweets }
      end
    end
  end
end

module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp /^https?:\/\/(mobile\.|www\.)?twitter\.com\/.+?\/status(es)?\/\d+$/
      always_https

      private

      def get_twitter_data
        response = Onebox::Helpers.fetch_response(url) rescue nil
        html = Nokogiri::HTML(response)
        twitter_data = {}
        html.css('meta').each do |m|
          if m.attribute('property') && m.attribute('property').to_s.match(/^og:/i)
            m_content = m.attribute('content').to_s.strip
            m_property = m.attribute('property').to_s.gsub('og:', '')
            twitter_data[m_property.to_sym] = m_content
          end
        end
        return twitter_data
      end

      def match
        @match ||= @url.match(%r{twitter\.com/.+?/status(es)?/(?<id>\d+)})
      end

      def twitter_data
        @twitter_data = get_twitter_data
      end

      def client
        Onebox.options.twitter_client
      end

      def twitter_api_credentials_present?
        client && !client.twitter_credentials_missing?
      end

      def raw
        if twitter_api_credentials_present?
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
        if twitter_api_credentials_present?
          client.prettify_tweet(raw)
        else
          twitter_data[:description].gsub(/“(.+?)”/im) { $1 } if twitter_data[:description]
        end
      end

      def timestamp
        if twitter_api_credentials_present?
          created_at = access(:created_at)
          date = DateTime.strptime(created_at, "%a %b %d %H:%M:%S %z %Y")
          user_offset = access(:user, :utc_offset).to_i
          offset = (user_offset >= 0 ? "+" : "-") + Time.at(user_offset.abs).gmtime.strftime("%H%M")
          date.new_offset(offset).strftime("%l:%M %p - %e %b %Y")
        else
          raw.css(".tweet-timestamp")[0].attribute('title')
        end
      end

      def title
        if twitter_api_credentials_present?
          "#{access(:user, :name)} (#{access(:user, :screen_name)})"
        else
          "#{raw.css('.tweet.permalink-tweet')[0].attribute('data-name')} (#{raw.css('.tweet.permalink-tweet')[0].attribute('data-screen-name')})"
        end
      end

      def avatar
        if twitter_api_credentials_present?
          access(:user, :profile_image_url_https)
        else
          twitter_data[:image].gsub!('400x400', 'normal') if twitter_data[:image]
        end
      end

      def data
        { link: link,
          tweet: tweet,
          timestamp: timestamp,
          title: title,
          avatar: avatar }
      end
    end
  end
end

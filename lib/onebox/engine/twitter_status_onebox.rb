# frozen_string_literal: true

module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp(/^https?:\/\/(mobile\.|www\.)?twitter\.com\/.+?\/status(es)?\/\d+(\/(video|photo)\/\d?+)?+(\/?\?.*)?\/?$/)
      always_https

      def http_params
        { 'User-Agent' => 'DiscourseBot/1.0' }
      end

      private

      def get_twitter_data
        response = Onebox::Helpers.fetch_response(url, headers: http_params) rescue nil
        html = Nokogiri::HTML(response)
        twitter_data = {}
        html.css('meta').each do |m|
          if m.attribute('property') && m.attribute('property').to_s.match(/^og:/i)
            m_content = m.attribute('content').to_s.strip
            m_property = m.attribute('property').to_s.gsub('og:', '').gsub(':', '_')
            twitter_data[m_property.to_sym] = m_content
          end
        end
        twitter_data
      end

      def match
        @match ||= @url.match(%r{twitter\.com/.+?/status(es)?/(?<id>\d+)})
      end

      def twitter_data
        @twitter_data ||= get_twitter_data
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
          next unless memo
          memo[key] || memo[key.to_s]
        end
      end

      def tweet
        if twitter_api_credentials_present?
          client.prettify_tweet(raw)&.strip
        else
          twitter_data[:description].gsub(/“(.+?)”/im) { $1 } if twitter_data[:description]
        end
      end

      def timestamp
        if twitter_api_credentials_present?
          date = DateTime.strptime(access(:created_at), "%a %b %d %H:%M:%S %z %Y")
          user_offset = access(:user, :utc_offset).to_i
          offset = (user_offset >= 0 ? "+" : "-") + Time.at(user_offset.abs).gmtime.strftime("%H%M")
          date.new_offset(offset).strftime("%-l:%M %p - %-d %b %Y")
        else
          attr_at_css(".tweet-timestamp", 'title')
        end
      end

      def title
        if twitter_api_credentials_present?
          access(:user, :name)
        else
          attr_at_css('.tweet.permalink-tweet', 'data-name')
        end
      end

      def screen_name
        if twitter_api_credentials_present?
          access(:user, :screen_name)
        else
          attr_at_css('.tweet.permalink-tweet', 'data-screen-name')
        end
      end

      def avatar
        if twitter_api_credentials_present?
          access(:user, :profile_image_url_https).sub('normal', '400x400')
        elsif twitter_data[:image]
          twitter_data[:image] unless twitter_data[:image_user_generated]
        end
      end

      def likes
        if twitter_api_credentials_present?
          prettify_number(access(:favorite_count).to_i)
        else
          attr_at_css(".request-favorited-popup", 'data-compact-localized-count')
        end
      end

      def retweets
        if twitter_api_credentials_present?
          prettify_number(access(:retweet_count).to_i)
        else
          attr_at_css(".request-retweeted-popup", 'data-compact-localized-count')
        end
      end

      def quoted_full_name
        if twitter_api_credentials_present?
          access(:quoted_status, :user, :name)
        else
          raw.css('.QuoteTweet-fullname')[0]&.text
        end
      end

      def quoted_screen_name
        if twitter_api_credentials_present?
          access(:quoted_status, :user, :screen_name)
        else
          attr_at_css(".QuoteTweet-innerContainer", "data-screen-name")
        end
      end

      def quoted_tweet
        if twitter_api_credentials_present?
          access(:quoted_status, :full_text)
        else
          raw.css('.QuoteTweet-text')[0]&.text
        end
      end

      def quoted_link
        if twitter_api_credentials_present?
          "https://twitter.com/#{quoted_screen_name}/status/#{access(:quoted_status, :id)}"
        else
          "https://twitter.com#{attr_at_css(".QuoteTweet-innerContainer", "href")}"
        end
      end

      def prettify_number(count)
        count > 0 ? client.prettify_number(count) : nil
      end

      def attr_at_css(css_property, attribute_name)
        raw.at_css(css_property)&.attr(attribute_name)
      end

      def data
        @data ||= {
          link: link,
          tweet: tweet,
          timestamp: timestamp,
          title: title,
          screen_name: screen_name,
          avatar: avatar,
          likes: likes,
          retweets: retweets,
          quoted_tweet: quoted_tweet,
          quoted_full_name: quoted_full_name,
          quoted_screen_name: quoted_screen_name,
          quoted_link: quoted_link
        }
      end
    end
  end
end

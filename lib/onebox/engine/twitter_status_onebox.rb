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

        begin
          extract_twitter_data!(html, twitter_data)
        rescue => e
          Rails.logger.warn("Failed to extract Twitter data: #{e.message}\n#{e.backtrace.join("\n")}")
        end

        twitter_data
      end

      def extract_twitter_data!(html, twitter_data)
        tweet_html = html.css('[itemtype="https://schema.org/SocialMediaPosting"]')[0]
        author_html = tweet_html.css('[itemprop="author"]')[0]
        twitter_data[:title] = author_html.css('[itemprop="givenName"]')[0]['content']
        twitter_data[:screen_name] = author_html.css('[itemprop="additionalName"]')[0]['content']
        twitter_data[:timestamp] = tweet_html.css('[itemprop="datePublished"]')[0]['content']
        tweet_html.children.each do |child|
          if child['itemprop'] == 'interactionStatistic'
            key = child.css('[itemprop="name"]')[0]['content']
            value = child.css('[itemprop="userInteractionCount"]')[0]['content']

            case key
            when 'Likes'
              twitter_data[:likes] = value
            when 'Retweets'
              twitter_data[:retweets] = value
            end
          end
        end

        tweet_html = tweet_html.css('[data-testid="tweet"]')[0]
        twitter_data[:image] = tweet_html.css('[data-testid="Tweet-User-Avatar"] img')[0]['src']
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
          twitter_data[:timestamp]&.to_datetime&.strftime("%-l:%M %p - %-d %b %Y")
        end
      end

      def title
        if twitter_api_credentials_present?
          access(:user, :name)
        else
          twitter_data[:title]
        end
      end

      def screen_name
        if twitter_api_credentials_present?
          access(:user, :screen_name)
        else
          twitter_data[:screen_name]
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
          prettify_number(twitter_data[:likes].to_i)
        end
      end

      def retweets
        if twitter_api_credentials_present?
          prettify_number(access(:retweet_count).to_i)
        else
          prettify_number(twitter_data[:retweets].to_i)
        end
      end

      def quoted_full_name
        if twitter_api_credentials_present?
          access(:quoted_status, :user, :name)
        else
          twitter_data[:quoted_full_name]
        end
      end

      def quoted_screen_name
        if twitter_api_credentials_present?
          access(:quoted_status, :user, :screen_name)
        else
          twitter_data[:quoted_screen_name]
        end
      end

      def quoted_tweet
        if twitter_api_credentials_present?
          access(:quoted_status, :full_text)
        else
          twitter_data[:quote_text]
        end
      end

      def quoted_link
        if twitter_api_credentials_present?
          "https://twitter.com/#{quoted_screen_name}/status/#{access(:quoted_status, :id)}"
        else
          "https://twitter.com#{twitter_data[:quote_url]}"
        end
      end

      def prettify_number(count)
        count > 0 ? client.prettify_number(count) : nil
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

# frozen_string_literal: true

module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include LayoutSupport
      include HTML
      include ActionView::Helpers::NumberHelper

      matches_domain("twitter.com", "www.twitter.com", "mobile.twitter.com", "x.com", "www.x.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/.+?/status(es)?/\d+(/(video|photo)/\d?)?(/?\?.*)?/?$})
      end

      def to_html
        raw.present? ? super : ""
      end

      private

      def get_twitter_data
        response =
          begin
            # We need to allow cross domain cookies to prevent an
            # infinite redirect loop between twitter.com and x.com
            Onebox::Helpers.fetch_response(
              url,
              headers: http_params,
              allow_cross_domain_cookies: true,
            )
          rescue StandardError
            return nil
          end
        html = Nokogiri.HTML(response)
        twitter_data = {}
        html
          .css("meta")
          .each do |m|
            if m.attribute("property") && m.attribute("property").to_s.match(/^og:/i)
              m_content = m.attribute("content").to_s.strip
              m_property = m.attribute("property").to_s.gsub("og:", "").gsub(":", "_")
              twitter_data[m_property.to_sym] = m_content
            end
          end
        twitter_data
      end

      def match
        @match ||= @url.match(%r{(twitter\.com|x\.com)/.+?/status(es)?/(?<id>\d+)})
      end

      def twitter_data
        @twitter_data ||= get_twitter_data
      end

      def guess_tweet_index
        usernames = meta_tags_data("additionalName").compact
        usernames.each_with_index do |username, index|
          return index if twitter_data[:url].to_s.include?(username)
        end
      end

      def tweet_index
        @tweet_index ||= guess_tweet_index
      end

      def client
        Onebox.options.twitter_client
      end

      def twitter_api_credentials_present?
        client && !client.twitter_credentials_missing?
      end

      def symbolize_keys(obj)
        case obj
        when Array
          obj.map { |item| symbolize_keys(item) }
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_sym] = symbolize_keys(value)
          end
        else
          obj
        end
      end

      def raw
        if twitter_api_credentials_present?
          @raw ||= symbolize_keys(client.status(match[:id]))
        else
          super
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
        if twitter_api_credentials_present? && (created_at = raw.dig(:data, :created_at))
          date = DateTime.strptime(created_at, "%Y-%m-%dT%H:%M:%S.%L%z")
          date.strftime("%-l:%M %p - %-d %b %Y")
        end
      end

      def title
        if twitter_api_credentials_present?
          raw.dig(:includes, :users)&.first&.dig(:name)
        else
          twitter_data[:title]
        end
      end

      def screen_name
        if twitter_api_credentials_present?
          raw.dig(:includes, :users)&.first&.dig(:username)
        else
          twitter_data[:title][/\(@([^\)\(]*)\) on X/, 1] if twitter_data[:title].present?
        end
      end

      def avatar
        if twitter_api_credentials_present?
          raw.dig(:includes, :users)&.first&.dig(:profile_image_url)
        else
          twitter_data[:image] if twitter_data[:image]&.include?("profile_images")
        end
      end

      def likes
        if twitter_api_credentials_present?
          prettify_number(raw.dig(:data, :public_metrics, :like_count).to_i)
        end
      end

      def retweets
        if twitter_api_credentials_present?
          prettify_number(raw.dig(:data, :public_metrics, :retweet_count).to_i)
        end
      end

      def is_reply
        if twitter_api_credentials_present?
          raw.dig(:data, :referenced_tweets)&.any? { |tweet| tweet.dig(:type) == "replied_to" }
        end
      end

      def quoted_full_name
        if twitter_api_credentials_present? && quoted_tweet_author.present?
          quoted_tweet_author[:name]
        end
      end

      def quoted_screen_name
        if twitter_api_credentials_present? && quoted_tweet_author.present?
          quoted_tweet_author[:username]
        end
      end

      def quoted_text
        quoted_tweet[:text] if twitter_api_credentials_present? && quoted_tweet.present?
      end

      def quoted_link
        if twitter_api_credentials_present?
          "https://twitter.com/#{quoted_screen_name}/status/#{quoted_status_id}"
        end
      end

      def quoted_status_id
        raw.dig(:data, :referenced_tweets)&.find { |ref| ref[:type] == "quoted" }&.dig(:id)
      end

      def quoted_tweet
        raw.dig(:includes, :tweets)&.find { |tweet| tweet[:id] == quoted_status_id }
      end

      def quoted_tweet_author
        raw.dig(:includes, :users)&.find { |user| user[:id] == quoted_tweet&.dig(:author_id) }
      end

      def prettify_number(count)
        if count > 0
          number_to_human(
            count,
            format: "%n%u",
            precision: 2,
            units: {
              thousand: "K",
              million: "M",
              billion: "B",
            },
          )
        end
      end

      def attr_at_css(css_property, attribute_name)
        raw.at_css(css_property)&.attr(attribute_name)
      end

      def meta_tags_data(attribute_name)
        data = []
        raw
          .css("meta")
          .each do |m|
            if m.attribute("itemprop") && m.attribute("itemprop").to_s.strip == attribute_name
              data.push(m.attribute("content").to_s.strip)
            end
          end
        data
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
          is_reply: is_reply,
          quoted_text: quoted_text,
          quoted_full_name: quoted_full_name,
          quoted_screen_name: quoted_screen_name,
          quoted_link: quoted_link,
        }
      end
    end
  end
end

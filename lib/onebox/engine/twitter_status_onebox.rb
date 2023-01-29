# frozen_string_literal: true

module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp(
        %r{^https?://(mobile\.|www\.)?twitter\.com/.+?/status(es)?/\d+(/(video|photo)/\d?+)?+(/?\?.*)?/?$},
      )
      always_https

      def self.===(other)
        client = Onebox.options.twitter_client
        client && !client.twitter_credentials_missing? && super
      end

      def http_params
        { "User-Agent" => "DiscourseBot/1.0" }
      end

      def to_html
        raw.present? ? super : ""
      end

      private

      def match
        @match ||= @url.match(%r{twitter\.com/.+?/status(es)?/(?<id>\d+)})
      end

      def client
        Onebox.options.twitter_client
      end

      def twitter_api_credentials_present?
        client && !client.twitter_credentials_missing?
      end

      def raw
        @raw ||= client.status(match[:id]).to_hash if twitter_api_credentials_present?
      end

      def access(*keys)
        keys.reduce(raw) do |memo, key|
          next unless memo
          memo[key] || memo[key.to_s]
        end
      end

      def tweet
        client.prettify_tweet(raw)&.strip
      end

      def timestamp
        date = DateTime.strptime(access(:created_at), "%a %b %d %H:%M:%S %z %Y")
        user_offset = access(:user, :utc_offset).to_i
        offset = (user_offset >= 0 ? "+" : "-") + Time.at(user_offset.abs).gmtime.strftime("%H%M")
        date.new_offset(offset).strftime("%-l:%M %p - %-d %b %Y")
      end

      def title
        access(:user, :name)
      end

      def screen_name
        access(:user, :screen_name)
      end

      def avatar
        access(:user, :profile_image_url_https).sub("normal", "400x400")
      end

      def likes
        prettify_number(access(:favorite_count).to_i)
      end

      def retweets
        prettify_number(access(:retweet_count).to_i)
      end

      def quoted_full_name
        access(:quoted_status, :user, :name)
      end

      def quoted_screen_name
        access(:quoted_status, :user, :screen_name)
      end

      def quoted_tweet
        access(:quoted_status, :full_text)
      end

      def quoted_link
        "https://twitter.com/#{quoted_screen_name}/status/#{access(:quoted_status, :id)}"
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
          quoted_link: quoted_link,
        }
      end
    end
  end
end

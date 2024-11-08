# frozen_string_literal: true

# lightweight Twitter api calls
class TwitterApi
  class << self
    BASE_URL = "https://api.twitter.com"
    URL_PARAMS = %w[
      tweet.fields=id,author_id,text,created_at,entities,referenced_tweets,public_metrics
      user.fields=id,name,username,profile_image_url
      media.fields=type,height,width,variants,preview_image_url,url
      expansions=attachments.media_keys,referenced_tweets.id.author_id
    ].freeze

    def prettify_tweet(tweet)
      text = tweet[:data][:text].dup.to_s
      if (entities = tweet[:data][:entities]) && (urls = entities[:urls])
        urls.each do |url|
          if !url[:display_url].start_with?("pic.twitter.com")
            text.gsub!(
              url[:url],
              "<a target='_blank' href='#{url[:expanded_url]}'>#{url[:display_url]}</a>",
            )
          else
            text.gsub!(url[:url], "")
          end
        end
      end
      text = link_hashtags_in link_handles_in text
      result = Rinku.auto_link(text, :all, 'target="_blank"').to_s

      if tweet[:includes] && media = tweet[:includes][:media]
        media.each do |m|
          if m[:type] == "photo"
            result << "<div class='tweet-images'><img class='tweet-image' src='#{m[:url]}' width='#{m[:width]}' height='#{m[:height]}'></div>"
          elsif m[:type] == "video" || m[:type] == "animated_gif"
            video_to_display =
              m[:variants]
                .select { |v| v[:content_type] == "video/mp4" }
                .sort { |v| v[:bit_rate] }
                .last # choose highest bitrate

            if video_to_display && url = video_to_display[:url]
              width = m[:width]
              height = m[:height]

              attributes =
                if m[:type] == "animated_gif"
                  %w[playsinline loop muted autoplay disableRemotePlayback disablePictureInPicture]
                else
                  %w[controls playsinline]
                end.join(" ")

              result << <<~HTML
                <div class='tweet-images'>
                  <div class='aspect-image-full-size' style='--aspect-ratio:#{width}/#{height};'>
                    <video class='tweet-video' #{attributes}
                      width='#{width}'
                      height='#{height}'
                      poster='#{m[:preview_image_url]}'>
                      <source src='#{url}' type="video/mp4">
                    </video>
                  </div>
                </div>
              HTML
            end
          end
        end
      end

      result
    end

    def tweet_for(id)
      JSON.parse(twitter_get(tweet_uri_for(id)))
    end
    alias_method :status, :tweet_for

    def twitter_credentials_missing?
      consumer_key.blank? || consumer_secret.blank?
    end

    protected

    def link_handles_in(text)
      text
        .gsub(/(?:^|\s)@\w+/) do |match|
          whitespace = match[0] == " " ? " " : ""
          handle = match.strip[1..]
          "#{whitespace}<a href='https://twitter.com/#{handle}' target='_blank'>@#{handle}</a>"
        end
        .strip
    end

    def link_hashtags_in(text)
      text
        .gsub(/(?:^|\s)#\w+/) do |match|
          whitespace = match[0] == " " ? " " : ""
          hashtag = match.strip[1..]
          "#{whitespace}<a href='https://twitter.com/search?q=%23#{hashtag}' target='_blank'>##{hashtag}</a>"
        end
        .strip
    end

    def tweet_uri_for(id)
      URI.parse "#{BASE_URL}/2/tweets/#{id}?#{URL_PARAMS.join("&")}"
    end

    def twitter_get(uri)
      request = Net::HTTP::Get.new(uri)
      request.add_field "Authorization", "Bearer #{bearer_token}"
      response = http(uri).request(request)

      if response.kind_of?(Net::HTTPTooManyRequests)
        Rails.logger.warn("Twitter API rate limit has been reached")
      end

      response.body
    end

    def authorization
      request = Net::HTTP::Post.new(auth_uri)

      request.add_field "Authorization", "Basic #{bearer_token_credentials}"
      request.add_field "Content-Type", "application/x-www-form-urlencoded;charset=UTF-8"

      request.set_form_data "grant_type" => "client_credentials"

      http(auth_uri).request(request).body
    end

    def bearer_token
      @access_token ||= JSON.parse(authorization).fetch("access_token")
    end

    def bearer_token_credentials
      Base64.strict_encode64(
        "#{UrlHelper.encode_component(consumer_key)}:#{UrlHelper.encode_component(consumer_secret)}",
      )
    end

    def auth_uri
      URI.parse "#{BASE_URL}/oauth2/token"
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap { |http| http.use_ssl = true }
    end

    def consumer_key
      SiteSetting.twitter_consumer_key
    end

    def consumer_secret
      SiteSetting.twitter_consumer_secret
    end
  end
end

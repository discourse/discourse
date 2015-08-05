module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*imgur\.com/)
      always_https

      def to_html
        twitter_data = get_twitter_data
        return "<video width='#{twitter_data[:"player:width"]}' height='#{twitter_data[:"player:height"]}' controls autoplay loop><source src='#{twitter_data[:"player:stream"]}' type='video/mp4'></video>" if twitter_data[:"player:stream"]
        return "<a href='#{url}' target='_blank'><img src='#{twitter_data[:image]}' alt='Imgur' height='#{twitter_data[:"image:height"]}' width='#{twitter_data[:"image:width"]}'></a>" if twitter_data[:image]
        return "<a href='#{url}' target='_blank'><img src='#{twitter_data[:"image0:src"]}' alt='Imgur'></a>" if twitter_data[:"image0:src"]
        return nil
      end

      private
      def get_twitter_data
        response = Onebox::Helpers.fetch_response(url)
        html = Nokogiri::HTML(response.body)
        twitter_data = {}
        html.css('meta').each do |m|
          if m.attribute('name') && m.attribute('name').to_s.match(/^twitter:/i)
            m_content = m.attribute('content').to_s.strip
            m_name = m.attribute('name').to_s.gsub('twitter:', '')
            twitter_data[m_name.to_sym] = m_content
          end
        end
        return twitter_data
      end
    end
  end
end

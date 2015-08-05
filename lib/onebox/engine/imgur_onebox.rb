module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*imgur\.com/)
      always_https

      def to_html
        imgur_data = get_imgur_data
        return "<video width='#{imgur_data[:"player:width"]}' height='#{imgur_data[:"player:height"]}' controls autoplay loop><source src='#{imgur_data[:"player:stream"]}' type='video/mp4'></video>" if imgur_data[:"player:stream"]
        return "<a href='#{url}' target='_blank'><img src='#{imgur_data[:image]}' alt='Imgur' height='#{imgur_data[:"image:height"]}' width='#{imgur_data[:"image:width"]}'></a>" if imgur_data[:image]
        return "<a href='#{url}' target='_blank'><img src='#{imgur_data[:"image0:src"]}' alt='Imgur'></a>" if imgur_data[:"image0:src"]
        return nil
      end

      private
      def get_imgur_data
        response = Onebox::Helpers.fetch_response(url)
        html = Nokogiri::HTML(response.body)
        imgur_data = {}
        html.css('meta').each do |m|
          if m.attribute('name') && m.attribute('name').to_s.match(/^twitter:/i)
            m_content = m.attribute('content').to_s.strip
            m_name = m.attribute('name').to_s.gsub('twitter:', '')
            imgur_data[m_name.to_sym] = m_content
          end
        end
        return imgur_data
      end
    end
  end
end

module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?imgur\.com/)
      always_https

      def to_html
        imgur_data = get_imgur_data
        return "<video width='#{imgur_data[:"player:width"]}' height='#{imgur_data[:"player:height"]}' controls autoplay loop><source src='#{imgur_data[:"player:stream"]}' type='video/mp4'><source src='#{imgur_data[:"player:stream"].gsub('mp4', 'webm')}' type='video/webm'></video>" if imgur_data[:"player:stream"]
        return "<div class='onebox imgur-album'><a href='#{url}' target='_blank'><span class='outer-box'><span class='inner-box'><span class='album-title'>[Album] #{imgur_data[:title]}</span></span></span><img src='#{imgur_data[:image]}' alt='Imgur'></a></div>" if is_album?
        return "<a href='#{url}' target='_blank'><img src='#{imgur_data[:image]}' alt='Imgur' height='#{imgur_data[:"image:height"]}' width='#{imgur_data[:"image:width"]}'></a>" if imgur_data[:image]
        return nil
      end

      def placeholder_html
        imgur_data = get_imgur_data
        return "<video width='#{imgur_data[:"player:width"]}' height='#{imgur_data[:"player:height"]}' controls autoplay loop><source src='#{imgur_data[:"player:stream"]}' type='video/mp4'><source src='#{imgur_data[:"player:stream"].gsub('mp4', 'webm')}' type='video/webm'></video>" if imgur_data[:"player:stream"]
        return "<img src='#{imgur_data[:image]}' alt='Imgur' height='#{imgur_data[:"image:height"]}' width='#{imgur_data[:"image:width"]}'>"
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

      def is_album?
        oembed_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response("http://api.imgur.com/oembed.json?url=#{url}").body))
        imgur_data_id = Nokogiri::HTML(oembed_data[:html]).xpath("//blockquote").attr("data-id")
        return !!(imgur_data_id.to_s =~ /a\//)
      end
    end
  end
end

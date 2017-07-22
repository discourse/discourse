module Onebox
  module Engine
    class WechatMpOnebox
      include Engine
      include LayoutSupport
      include HTML

      always_https
      matches_regexp(/^https?:\/\/mp\.weixin\.qq\.com\/s.*$/)

      def tld
        @tld || @@matcher.match(@url)["tld"]
      end

      def http_params
        {
          'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3',
          'Accept-Encoding' => 'plain'
        }
      end

      private

      def extract_script_value(var_name)
        if (script_elem = raw.css("script").select{|script| script.inner_text.include? "var #{var_name} = "}) && script_elem.any?
          e = Nokogiri::HTML(script_elem[0].inner_text.match(/var\s+#{Regexp.quote(var_name)}\s+=\s+"(.*?)";/)[1])
          return CGI::unescapeHTML(e.text.scan(/(?:\\x([a-f0-9]{2}))|(.)/i).map { |x| x[0] ? [x[0].to_i(16)].pack('U'): x[1] }.join)
        end
      end
      
      # TODO need to handle hotlink protection from wechat
      def image
        if banner_image = extract_script_value("msg_cdn_url")
          return banner_image
        end

        if (main_image = raw.css("img").select{|img| not img['class']}) && main_image.any?
          attributes = main_image.first.attributes

          return attributes["data-src"].to_s if attributes["data-src"]
        end
      end

      def data
        title = CGI.unescapeHTML(raw.css("title").inner_text)
        by_info = CGI.unescapeHTML(raw.css("span.rich_media_meta_text.rich_media_meta_nickname").inner_text)

        result = {
          link: extract_script_value("msg_link") || link,
          title: title,
          image: image,
          description: extract_script_value("msg_desc"),
          by_info: by_info
        }

        result
      end
    end
  end
end

module Onebox
  module Helpers
    def self.symbolize_keys(hash)
      return {} if hash.nil?

      hash.inject({}){|result, (key, value)|
        new_key = case key
                  when String then key.to_sym
                  else key
                  end
        new_value = case value
                    when Hash then symbolize_keys(value)
                    else value
                    end
        result[new_key] = new_value
        result
      }
    end

    def self.clean(html)
      html.gsub(/<[^>]+>/, ' ').gsub(/\n/, '')
    end

    def self.fetch_response(location, limit = 5, domain = nil, headers = nil)
      raise Net::HTTPError.new('HTTP redirect too deep', location) if limit == 0

      uri = URI(location)
      if !uri.host
        uri = URI("#{domain}#{location}")
      end
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = Onebox.options.connect_timeout
      http.read_timeout = Onebox.options.timeout
      if uri.is_a?(URI::HTTPS)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      response = http.request_get(uri.request_uri,headers)

      cookie = response.get_fields('set-cookie')
      if (cookie)
        header = {'cookie' => cookie.join("")}
      end
      header = nil unless header.is_a? Hash

      case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch_response(response['location'], limit - 1, "#{uri.scheme}://#{uri.host}",header)
        else
          response.error!
      end
    end

    def self.click_to_scroll_div(width = 690, height = 400)
      "<div style=\"background:transparent;position:relative;width:#{width}px;height:#{height}px;top:#{height}px;margin-top:-#{height}px;\" onClick=\"style.pointerEvents='none'\"></div>"
    end
  end
end

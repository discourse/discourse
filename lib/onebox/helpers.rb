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

  end
end


module Onebox
  module Engine
    class StackExchangeOnebox
      include Engine
      include LayoutSupport
      include JSON

      def self.domains
        %w(stackexchange stackoverflow superuser serverfault askubuntu)
      end

      matches_regexp /^http:\/\/(?:(?:(?<subsubdomain>\w*)\.)?(?<subdomain>\w*)\.)?(?<domain>#{domains.join('|')})\.com\/(?:questions|q)\/(?<question>\d*)/

      private

      def match
        @match ||= @url.match(@@matcher)
      end

      def url
        domain = URI(@url).host
        "http://api.stackexchange.com/2.1/questions/#{match[:question]}?site=#{domain}"
      end

      def data
        return @data if @data

        result = raw['items'][0]
        if result
          result['creation_date'] =
            Time.at(result['creation_date'].to_i).strftime("%I:%M%p - %d %b %y")

          result['tags'] = result['tags'].take(4).join(', ')
        end
        @data = result
      end
    end
  end
end

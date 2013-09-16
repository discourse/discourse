require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class StackExchangeOnebox < HandlebarsOnebox

    unless defined? DOMAINS
      DOMAINS = [
        'stackexchange',
        'stackoverflow',
        'superuser',
        'serverfault',
        'askubuntu'
      ]
    end

    # http://rubular.com/r/V3T0I1VTPn
    unless defined? REGEX
      REGEX = /^http:\/\/(?:(?:(?<subsubdomain>\w*)\.)?(?<subdomain>\w*)\.)?(?<domain>#{DOMAINS.join('|')})\.com\/(?:questions|q)\/(?<question>\d*)/
    end

    matcher REGEX
    favicon 'stackexchange.png'

    def translate_url
      @url.match(REGEX) do |match|
        site = if match[:domain] == 'stackexchange'
          [match[:subsubdomain],match[:subdomain]].compact.join('.')
        else
          [match[:subdomain],match[:domain]].compact.join('.')
        end

        ["http://api.stackexchange.com/2.1/",
         "questions/#{match[:question]}",
         "?site=#{site}"
        ].join
      end
    end

    def parse(data)
      result = JSON.parse(data)['items'].first

      if result
        result['creation_date'] =
          Time.at(result['creation_date'].to_i).strftime("%I:%M%p - %d %b %y")

        result['tags'] = result['tags'].take(4).join(', ')
      end

      result
    end
  end
end

require "cgi"

module Onebox
  module Engine
    module StandardEmbed

      def self.oembed_providers
        @@oembed_providers ||= {}
      end

      def self.add_oembed_provider(regexp, endpoint)
        oembed_providers[regexp] = endpoint
      end

      def self.opengraph_providers
        @@opengraph_providers ||= []
      end

      def self.add_opengraph_provider(regexp)
        opengraph_providers << regexp
      end

      # Some oembed providers (like meetup.com) don't provide links to themselves
      add_oembed_provider(/www\.meetup\.com\//, 'http://api.meetup.com/oembed')
      # In order to support Private Videos
      add_oembed_provider(/vimeo\.com\//, 'https://vimeo.com/api/oembed.json')
      # NYT requires login so use oembed only
      add_oembed_provider(/nytimes\.com\//, 'https://www.nytimes.com/svc/oembed/json/')

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts) || super
      end

      def raw
        return @raw if @raw

        og = get_opengraph
        twitter = get_twitter
        oembed = get_oembed

        @raw = {}

        og.each { |k, v| @raw[k] ||= v unless Onebox::Helpers::blank?(v) }
        twitter.each { |k, v| @raw[k] ||= v unless Onebox::Helpers::blank?(v) }
        oembed.each { |k, v| @raw[k] ||= v unless Onebox::Helpers::blank?(v) }

        @raw
      end

      protected

        def html_doc
          @html_doc ||= Nokogiri::HTML((Onebox::Helpers.fetch_response(url) rescue nil))
        end

        def get_oembed
          oembed_url = nil

          StandardEmbed.oembed_providers.each do |regexp, endpoint|
            if url =~ regexp
              oembed_url = "#{endpoint}?url=#{url}"
              break
            end
          end

          if html_doc
            if Onebox::Helpers.blank?(oembed_url)
              application_json = html_doc.at("//link[@type='application/json+oembed']/@href")
              oembed_url = application_json.value if application_json
            end

            if Onebox::Helpers.blank?(oembed_url)
              text_json = html_doc.at("//link[@type='text/json+oembed']/@href")
              oembed_url ||= text_json.value if text_json
            end
          end

          return {} if Onebox::Helpers.blank?(oembed_url)

          json_response = Onebox::Helpers.fetch_response(oembed_url) rescue "{}"
          oe = Onebox::Helpers.symbolize_keys(::MultiJson.load(json_response))

          # never use oembed from WordPress 4.4 (it's broken)
          oe.delete(:html) if oe[:html] && oe[:html]["wp-embedded-content"]

          oe
        rescue Errno::ECONNREFUSED, Net::HTTPError, Net::HTTPFatalError, MultiJson::LoadError
          {}
        end

        def get_opengraph
          return {} unless html_doc

          og = {}

          html_doc.css('meta').each do |m|
            if (m["property"] && m["property"][/^og:(.+)$/i]) || (m["name"] && m["name"][/^og:(.+)$/i])
              value = (m["content"] || m["value"]).to_s
              og[$1.tr('-:','_').to_sym] ||= value unless Onebox::Helpers::blank?(value)
            end
          end

          # Attempt to retrieve the title from the meta tag
          title_element = html_doc.at_css('title')
          if title_element && title_element.text
            og[:title] ||= title_element.text unless Onebox::Helpers.blank?(title_element.text)
          end

          og
        end

        def get_twitter
          return {} unless html_doc

          twitter = {}

          html_doc.css('meta').each do |m|
            if (m["property"] && m["property"][/^twitter:(.+)$/i]) || (m["name"] && m["name"][/^twitter:(.+)$/i])
              value = (m["content"] || m["value"]).to_s
              twitter[$1.tr('-:','_').to_sym] ||= value unless Onebox::Helpers::blank?(value)
            end
          end

          twitter
        end

    end
  end
end

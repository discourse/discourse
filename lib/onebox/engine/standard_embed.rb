module Onebox
  module Engine
    module StandardEmbed

      def self.oembed_providers
        @@oembed_providers ||= {}
      end

      def self.opengraph_providers
        @@opengraph_providers ||= Array.new
      end

      def self.add_oembed_provider(regexp, endpoint)
        oembed_providers[regexp] = endpoint
      end

      def self.add_opengraph_provider(regexp)
        opengraph_providers.push(regexp)
      end

      # Some oembed providers (like meetup.com) don't provide links to themselves
      add_oembed_provider /www\.flickr\.com\//, 'http://www.flickr.com/services/oembed.json'
      add_oembed_provider /(.*\.)?gfycat\.com\//, 'http://gfycat.com/cajax/oembed'
      add_oembed_provider /www\.kickstarter\.com\//, 'https://www.kickstarter.com/services/oembed'
      add_oembed_provider /www\.meetup\.com\//, 'http://api.meetup.com/oembed'
      add_oembed_provider /www\.ted\.com\//, 'http://www.ted.com/services/v1/oembed.json'
      add_oembed_provider /(.*\.)?vimeo\.com\//, 'http://vimeo.com/api/oembed.json'

      # Sites that work better with OpenGraph
      # add_opengraph_provider /gfycat\.com\//

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
      end

      def raw
        return @raw if @raw

        StandardEmbed.oembed_providers.each do |regexp, endpoint|
          if url =~ regexp
            fetch_oembed_raw("#{endpoint}?url=#{url}")
            return @raw if @raw
          end
        end

        response = Onebox::Helpers.fetch_response(url)
        html_doc = Nokogiri::HTML(response.body)

        StandardEmbed.opengraph_providers.each do |regexp|
          if url =~ regexp
            @raw = parse_open_graph(html_doc, url)
            return @raw if @raw
          end
        end

        # Determine if we should use oEmbed or OpenGraph (prefers oEmbed)
        oembed_alternate = html_doc.at("//link[@type='application/json+oembed']") || html_doc.at("//link[@type='text/json+oembed']")
        fetch_oembed_raw(oembed_alternate)

        open_graph = parse_open_graph(html_doc, url)
        if @raw
          @raw[:image] = open_graph.images.first if @raw[:image].nil? && open_graph && open_graph.images
          return @raw
        end

        @raw = open_graph
      end

      private

      def fetch_oembed_raw(oembed_url)
        return unless oembed_url
        oembed_url = oembed_url['href'] unless oembed_url['href'].nil?
        @raw = Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response(oembed_url).body))
      rescue Errno::ECONNREFUSED, Net::HTTPError, MultiJson::LoadError
        @raw = nil
      end

      def parse_open_graph(html, og_url)
        og = Struct.new(:url, :type, :title, :description, :images, :metadata, :html).new
        og.url = og_url
        og.images = []
        og.metadata = {}

        attrs_list = %w(title url type description)
        html.css('meta').each do |m|
          if m.attribute('property') && m.attribute('property').to_s.match(/^og:/i)
            m_content = m.attribute('content').to_s.strip
            m_name = m.attribute('property').to_s.gsub('og:', '')
            og.metadata[m_name.to_sym] ||= []
            og.metadata[m_name.to_sym].push m_content
            if m_name == "image"
              image_uri = URI.parse(m_content) rescue nil
              if image_uri
                if image_uri.host.nil?
                  image_uri.host = URI.parse(og_url).host
                end
                og.images.push image_uri.to_s
              end
            elsif attrs_list.include? m_name
              og.send("#{m_name}=", m_content) unless m_content.empty?
            end
          end
        end

        og
      end
    end
  end
end

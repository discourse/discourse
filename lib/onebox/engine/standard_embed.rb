module Onebox
  module Engine
    module StandardEmbed
      def raw
        return @raw if @raw
        response = Onebox::Helpers.fetch_response(url)
        html_doc = Nokogiri::HTML(response.body)

        # Determine if we should use OEmbed or OpenGraph
        oembed_alternate = html_doc.at("//link[@type='application/json+oembed']") || html_doc.at("//link[@type='text/json+oembed']")
        if oembed_alternate
          # If the oembed request fails, we can still try the opengraph below.
          begin
            @raw = Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response(oembed_alternate['href']).body))
          rescue Errno::ECONNREFUSED, Net::HTTPError, MultiJson::LoadError
            @raw = nil
          end
        end

        open_graph = parse_open_graph(html_doc, url)
        if @raw
          @raw[:image] = open_graph.images.first if @raw[:image].nil? && open_graph && open_graph.images

          return @raw
        end

        @raw = open_graph
      end

      private

      def parse_open_graph(html, url)
        og = Struct.new(:url, :type, :title, :description, :images, :metadata, :html).new
        og.url = url
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
                  image_uri.host = URI.parse(url).host
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

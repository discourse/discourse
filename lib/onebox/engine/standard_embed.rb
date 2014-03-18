module Onebox
  module Engine
    module StandardEmbed

      def raw
        return @raw if @raw
        response = fetch_response(url)

        html_doc = Nokogiri::HTML(response.body)

        # Determine if we should use OEmbed or OpenGraph
        oembed_alternate = html_doc.at("//link[@type='application/json+oembed']") || html_doc.at("//link[@type='text/json+oembed']")
        if oembed_alternate
          # If the oembed request fails, we can still try the opengraph below.
          begin
            @raw = Onebox::Helpers.symbolize_keys(::MultiJson.load(fetch_response(oembed_alternate['href']).body))
          rescue Errno::ECONNREFUSED, Net::HTTPError, MultiJson::LoadError
            @raw = nil
          end
        end

        open_graph = OpenGraph.new(response.body, false)
        if @raw
          @raw[:image] = open_graph.images.first if @raw[:image].nil? && open_graph && open_graph.images

          return @raw
        end

        @raw = open_graph
      end

      private

      def fetch_response(location, limit = 3)
        raise Net::HTTPError.new('HTTP redirect too deep', location) if limit == 0

        uri = URI(location)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = Onebox.options.connect_timeout
        http.read_timeout = Onebox.options.timeout
        response = http.request_get(uri.request_uri)

        case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch_response(response['location'], limit - 1)
        else
          response.error!
        end
      end

    end
  end
end
